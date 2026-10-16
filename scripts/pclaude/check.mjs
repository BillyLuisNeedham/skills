#!/usr/bin/env node
// Fails on anything in skills/pclaude/ that still belongs to Cursor or to
// pstack, and on links to skills or files that do not exist in pclaude.
//
//   node scripts/pclaude/check.mjs <pclaude-dir> <allowlist-file>
//
// Prints one line per hit, `path:line: [rule] matched text`, then a count.
// Exits 1 when any hit is not allowlisted, or the allowlist is malformed.
// The allowlist format is described at the top of scripts/pclaude-check.allow.

import fs from "node:fs";
import path from "node:path";

const posix = path.posix;

// Files the check never reads: LICENSE is upstream's text, copied verbatim,
// and UPSTREAM holds a sha.
const SKIP_FILES = new Set(["LICENSE", "UPSTREAM"]);
const BINARY_EXTENSIONS = new Set([".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".pdf"]);

// Text patterns, checked on every line of every text file. Spec section 3
// lists the Cursor-isms; `Cursor`, the unported skill names and conflict
// markers are additions that catch the same leftovers.
const TEXT_RULES = [
  { id: "cursor:grok", re: /grok/gi },
  { id: "cursor:AskQuestion", re: /AskQuestion/g },
  { id: "cursor:api2.cursor.sh", re: /api2\.cursor\.sh/g },
  { id: "cursor:.cursor", re: /\.cursor(?!\.sh)/g },
  { id: "cursor:.mdc", re: /\.mdc\b/g },
  { id: "cursor:deslop", re: /deslop/gi },
  { id: "cursor:control-ui", re: /control-ui/g },
  { id: "cursor:control-cli", re: /control-cli/g },
  { id: "cursor:cursor-team-kit", re: /cursor-team-kit/g },
  {
    id: "cursor:Task-tool",
    re: /`Task`|\bTask (?:tool|calls?|spawns?|subagents?|schema|response|prompt|`model`)\b|\b(?:every|omit|one|the) Task\b/g,
  },
  { id: "cursor:mode-true", re: /\bmode:\s*true\b/g },
  { id: "cursor:Cursor", re: /\bCursor\b/g },
  { id: "pstack", re: /(?<![A-Za-z])pstack/gi },
  { id: "unported-skill", re: /(?<![\w-])(?:make-bot-ui|setup-pstack|setup-pclaude)(?![\w-])/g },
  { id: "conflict-marker", re: /^(?:<{7}|\|{7}|>{7})(?: |$)/g },
];

// Frontmatter keys that have no meaning in Claude Code skills.
const FRONTMATTER_RULES = [
  { id: "cursor:reminder-frontmatter", re: /^reminder:/, files: /\.md$/ },
  { id: "cursor:mode-frontmatter", re: /^mode:/, files: /(^|\/)SKILL\.md$/ },
  { id: "cursor:icon-frontmatter", re: /^icon:/, files: /(^|\/)SKILL\.md$/ },
];

function walk(root, rel = "") {
  const out = [];
  for (const entry of fs.readdirSync(path.join(root, rel), { withFileTypes: true })) {
    const r = rel ? `${rel}/${entry.name}` : entry.name;
    if (entry.isDirectory()) {
      if (entry.name === "node_modules" || entry.name === ".git") continue;
      out.push(...walk(root, r));
    } else if (entry.isFile()) out.push(r);
  }
  return out;
}

function isBinary(file, buf) {
  if (BINARY_EXTENSIONS.has(path.extname(file).toLowerCase())) return true;
  return buf.subarray(0, 8000).includes(0);
}

function globToRegExp(glob) {
  let re = "";
  for (let i = 0; i < glob.length; i++) {
    const c = glob[i];
    if (c === "*" && glob[i + 1] === "*" && glob[i + 2] === "/") {
      re += "(?:.*/)?";
      i += 2;
    } else if (c === "*" && glob[i + 1] === "*") {
      re += ".*";
      i += 1;
    } else if (c === "*") re += "[^/]*";
    else if (c === "?") re += "[^/]";
    else re += c.replace(/[.+^${}()|[\]\\]/g, "\\$&");
  }
  return new RegExp(`^${re}$`);
}

// Parses the allowlist. Each entry is `<glob>\t<exact text>`, and the block it
// sits in must open with a `#` comment saying why. A blank line ends a block.
export function parseAllowlist(text, file = "allowlist") {
  const entries = [];
  const errors = [];
  let commented = false;
  text.split("\n").forEach((raw, i) => {
    const line = raw.replace(/\r$/, "");
    if (line.trim() === "") {
      commented = false;
      return;
    }
    if (line.startsWith("#")) {
      commented = true;
      return;
    }
    const tab = line.indexOf("\t");
    if (tab <= 0 || tab === line.length - 1) {
      errors.push(`${file}:${i + 1}: entry is not "<glob><TAB><exact text>"`);
      return;
    }
    if (!commented) {
      errors.push(`${file}:${i + 1}: entry has no comment above it saying why it is allowed`);
      return;
    }
    entries.push({ line: i + 1, glob: line.slice(0, tab), re: globToRegExp(line.slice(0, tab)), text: line.slice(tab + 1), used: false });
  });
  return { entries, errors };
}

function allowed(entries, file, lineText, start, end) {
  for (const e of entries) {
    if (!e.re.test(file)) continue;
    let from = lineText.indexOf(e.text);
    while (from !== -1) {
      if (from <= start && end <= from + e.text.length) {
        e.used = true;
        return true;
      }
      from = lineText.indexOf(e.text, from + 1);
    }
  }
  return false;
}

// The pclaude names that exist, as skill dirs (pclaude-<name>/) and agents
// (agents/pclaude-<name>.md).
function pclaudeNames(root) {
  const names = new Set();
  for (const d of fs.readdirSync(root, { withFileTypes: true })) {
    if (d.isDirectory() && d.name.startsWith("pclaude-")) names.add(d.name);
  }
  const agents = path.join(root, "agents");
  if (fs.existsSync(agents)) {
    for (const f of fs.readdirSync(agents)) {
      if (f.startsWith("pclaude-") && f.endsWith(".md")) names.add(f.slice(0, -3));
    }
  }
  return names;
}

const isConcrete = (p) => !/[<>*{}$]/.test(p);

// Reference checks. Each yields [start, end, rule, text] for a reference that
// points at nothing.
function referenceHits(root, names, file, line) {
  const hits = [];
  const exists = (rel) => fs.existsSync(path.join(root, rel));
  const isMd = file.endsWith(".md");

  if (isMd) {
    const links = [];
    for (const m of line.matchAll(/\]\(([^)\s]+)/g)) links.push([m.index + 2, m[1]]);
    for (const m of line.matchAll(/^(\s*\[[^\]]+\]:\s+)(\S+)/g)) links.push([m.index + m[1].length, m[2]]);
    for (const m of line.matchAll(/\bsrc=["']([^"']+)/g)) links.push([m.index + 5, m[1]]);
    for (const [at, target] of links) {
      if (/^([a-z][a-z0-9+.-]*:|#|\/|~)/i.test(target)) continue;
      const p = target.replace(/[#?].*$/, "");
      if (!p || !isConcrete(p)) continue;
      const resolved = posix.normalize(posix.join(posix.dirname(file), decodeURI(p)));
      if (resolved.startsWith("..") || !exists(resolved)) {
        hits.push([at, at + target.length, "dangling-link", target]);
      }
    }
  }

  // ~/.claude/skills/pclaude-<name>/<path> and skills/pclaude/<path>.
  for (const m of line.matchAll(/~\/\.claude\/skills\/(pclaude-[\w.-]+(?:\/[\w.-]+)*)/g)) {
    const rel = m[1].replace(/[.,:;)]+$/, "");
    if (!exists(rel)) hits.push([m.index, m.index + m[0].length, "dangling-path", m[0]]);
  }
  for (const m of line.matchAll(/(?<![\w/.-])skills\/pclaude\/([\w.-]+(?:\/[\w.-]+)*)/g)) {
    const rel = m[1].replace(/[.,:;)]+$/, "");
    if (!exists(rel)) hits.push([m.index, m.index + m[0].length, "dangling-path", m[0]]);
  }

  // Any pclaude-<name> must name a skill or an agent; pclaude-principles/<x>
  // must name a leaf.
  for (const m of line.matchAll(/(?<![\w-])pclaude-[a-z0-9]+(?:-[a-z0-9]+)*/g)) {
    const name = m[0];
    if (!names.has(name)) {
      hits.push([m.index, m.index + name.length, "unknown-skill", name]);
      continue;
    }
    if (name === "pclaude-principles") {
      const leaf = line.slice(m.index + name.length).match(/^\/([a-z0-9-]+)(\.md)?(?![\w/-])/);
      if (leaf && leaf[1] !== "SKILL" && !exists(`${name}/${leaf[1]}.md`)) {
        hits.push([m.index, m.index + name.length + leaf[0].length, "unknown-principle", name + leaf[0]]);
      }
    }
  }
  return hits;
}

export function check(root, allowlistText) {
  const { entries, errors } = parseAllowlist(allowlistText);
  const names = pclaudeNames(root);
  const hits = [];
  for (const file of walk(root).sort()) {
    if (SKIP_FILES.has(file)) continue;
    const buf = fs.readFileSync(path.join(root, file));
    if (isBinary(file, buf)) continue;
    const lines = buf.toString("utf8").split("\n");
    let inFrontmatter = file.endsWith(".md") && lines[0] === "---";
    lines.forEach((line, i) => {
      const found = [];
      if (inFrontmatter && i > 0 && line === "---") inFrontmatter = false;
      else if (inFrontmatter && i > 0) {
        for (const r of FRONTMATTER_RULES) {
          if (r.files.test(file) && r.re.test(line)) found.push([0, line.length, r.id, line]);
        }
      }
      for (const r of TEXT_RULES) {
        for (const m of line.matchAll(r.re)) found.push([m.index, m.index + m[0].length, r.id, m[0]]);
      }
      found.push(...referenceHits(root, names, file, line));
      for (const [start, end, rule, text] of found) {
        if (allowed(entries, file, line, start, end)) continue;
        hits.push(`${file}:${i + 1}: [${rule}] ${text}`);
      }
    });
  }
  const unused = entries.filter((e) => !e.used).map((e) => `allowlist line ${e.line}: unused entry ${e.glob}\t${e.text}`);
  return { hits, errors, unused };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const [root, allowFile] = process.argv.slice(2);
  if (!root || !allowFile) {
    console.error("usage: check.mjs <pclaude-dir> <allowlist-file>");
    process.exit(2);
  }
  if (!fs.existsSync(root)) {
    console.error(`pclaude-check: ${root} does not exist`);
    process.exit(2);
  }
  const allowText = fs.existsSync(allowFile) ? fs.readFileSync(allowFile, "utf8") : "";
  const { hits, errors, unused } = check(root, allowText);
  for (const e of errors) console.log(`ERROR ${e}`);
  for (const h of hits) console.log(h);
  for (const u of unused) console.log(`warning: ${u}`);
  if (errors.length || hits.length) {
    console.log(`pclaude-check: FAILED, ${hits.length} hit(s)${errors.length ? `, ${errors.length} allowlist error(s)` : ""}`);
    process.exit(1);
  }
  console.log("pclaude-check: clean");
}
