#!/usr/bin/env node
// Renders an upstream pstack tree into pclaude's layout, with every reference
// renamed. The same upstream tree always renders the same bytes.
//
//   node scripts/pclaude/render.mjs <upstream-pstack-dir> <out-dir>
//
// <upstream-pstack-dir> is the `pstack/` folder of cursor/plugins at one sha.
// <out-dir> must not exist yet; it receives the files as they belong under
// skills/pclaude/.
//
// Layout (upstream path relative to pstack/ -> path relative to skills/pclaude/):
//   skills/<name>/...                 -> pclaude-<name>/...
//   skills/poteto-help/...            -> pclaude-help/...
//   skills/principle-<name>/SKILL.md  -> pclaude-principles/<name>.md
//   agents/<name>.md                  -> agents/pclaude-<name>.md
//   docs/guide/...                    -> docs/...
// Not rendered are skills/make-bot-ui and skills/setup-pstack (not ported) and
// everything else upstream (README, plugin manifests, assets, automations,
// docs/harness, LICENSE; the update script copies LICENSE verbatim).
//
// Rename rules, applied to every text file in this order:
//   1. Frontmatter `name:` of a skill or agent becomes its pclaude name.
//      Principle leaves keep theirs; they stop being skills.
//   2. Exact KEEP_LITERALS strings are left alone (a skill name used as a word).
//   3. URLs are left alone, since they point at upstream.
//   4. Relative links (markdown `](x)`, `[x]: y` and `src="x"`) and plain-text
//      upstream paths (`pstack/skills/x/...`, `skills/x/...`, `../x/`) are
//      resolved against the upstream tree and re-pointed at the file's pclaude
//      home. A path with no pclaude home (the upstream README, setup-pstack) is
//      left verbatim, so the check flags it.
//   5. Skill and agent names become pclaude names: `/name` commands, exact
//      `name` backtick spans, **name** bold spans (single-word names included,
//      e.g. **how**), and bare whole-token names that hold a hyphen. Principle
//      names (`principle-<name>`) are left as prose names; their links and
//      paths are re-pointed by rule 4.
//   6. The names of skills that are not ported are left verbatim.
//   7. Every remaining `pstack` becomes `pclaude`, case kept. A `pstack` inside
//      a word (`upstack`) is not touched.

import fs from "node:fs";
import path from "node:path";

const P = "pclaude";
const EXCLUDED_SKILLS = ["make-bot-ui", "setup-pstack"];
const RENAMED_SKILLS = { "poteto-help": "help" };
// A skill name meant as a plain word, as in update-skills.sh's pstack sync.
const KEEP_LITERALS = ["`candidate`, or `arena`", "Layered technical-writing standard"];
const BINARY_EXTENSIONS = new Set([".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".pdf"]);

const posix = path.posix;

function walk(root, rel = "") {
  const out = [];
  for (const entry of fs.readdirSync(path.join(root, rel), { withFileTypes: true })) {
    const r = rel ? `${rel}/${entry.name}` : entry.name;
    if (entry.isDirectory()) out.push(...walk(root, r));
    else if (entry.isFile()) out.push(r);
  }
  return out;
}

function escapeRe(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function alt(names) {
  if (names.length === 0) return "(?!)";
  return [...names].sort((a, b) => b.length - a.length).map(escapeRe).join("|");
}

export function buildModel(upstreamDir) {
  const skills = fs
    .readdirSync(path.join(upstreamDir, "skills"), { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name);
  const agentsDir = path.join(upstreamDir, "agents");
  const agents = fs.existsSync(agentsDir)
    ? fs.readdirSync(agentsDir).filter((f) => f.endsWith(".md")).map((f) => f.slice(0, -3))
    : [];
  const principles = skills.filter((s) => s.startsWith("principle-"));
  const ported = skills.filter((s) => !s.startsWith("principle-") && !EXCLUDED_SKILLS.includes(s));
  const skillName = (s) => `${P}-${RENAMED_SKILLS[s] ?? s}`;
  return { skills, agents, principles, ported, skillName };
}

// Maps an upstream path (relative to pstack/, file or directory, no leading or
// trailing slash) to its path relative to skills/pclaude/, or null when it has
// no pclaude home.
export function mapPath(model, up) {
  const parts = up.split("/");
  if (parts[0] === "skills" && parts.length >= 2) {
    const s = parts[1];
    const rest = parts.slice(2);
    if (EXCLUDED_SKILLS.includes(s) || !model.skills.includes(s)) return null;
    if (s.startsWith("principle-")) {
      const leaf = s.slice("principle-".length);
      if (rest.length === 0 || (rest.length === 1 && rest[0] === "SKILL.md")) {
        return `${P}-principles/${leaf}.md`;
      }
      return [`${P}-principles`, leaf, ...rest].join("/");
    }
    return [model.skillName(s), ...rest].join("/");
  }
  if (parts[0] === "skills" && parts.length === 1) return "";
  if (parts[0] === "agents" && parts.length === 2 && parts[1].endsWith(".md")) {
    const a = parts[1].slice(0, -3);
    return model.agents.includes(a) ? `agents/${P}-${a}.md` : null;
  }
  if (parts[0] === "agents" && parts.length === 1) return "agents";
  if (parts[0] === "docs" && parts[1] === "guide") {
    return ["docs", ...parts.slice(2)].join("/");
  }
  return null;
}

function relLink(fromFile, toPath, trailingSlash, original) {
  let r = posix.relative(posix.dirname(fromFile), toPath || ".");
  if (r === "") r = ".";
  if (original.startsWith("./") && !r.startsWith(".")) r = `./${r}`;
  if (trailingSlash && !r.endsWith("/")) r += "/";
  return r;
}

// Re-points one relative link target written in upstream file `fromUp`, whose
// pclaude home is `fromP`. Returns null to leave the target verbatim.
function repointLink(model, fromUp, fromP, target) {
  if (/^([a-z][a-z0-9+.-]*:|#|\/|~)/i.test(target) || target.includes("\x00")) return null;
  const m = target.match(/^([^#?]*)(.*)$/);
  const [pathPart, suffix] = [m[1], m[2]];
  if (pathPart === "") return null;
  const resolved = posix.normalize(posix.join(posix.dirname(fromUp), pathPart));
  if (resolved.startsWith("..")) return null;
  const trailing = pathPart.endsWith("/");
  const mapped = mapPath(model, resolved.replace(/\/$/, ""));
  if (mapped === null) return null;
  const isLeaf = mapped.endsWith(".md") && !pathPart.endsWith(".md");
  const r = relLink(fromP, mapped, trailing && !isLeaf, pathPart);
  return r === pathPart ? null : r + suffix;
}

function caseLike(match, word) {
  if (match === match.toUpperCase()) return word.toUpperCase();
  if (match[0] === match[0].toUpperCase()) return word[0].toUpperCase() + word.slice(1);
  return word;
}

export function renameText(model, fromUp, fromP, text) {
  const { ported, agents, skillName } = model;
  const nameOf = (n) => (agents.includes(n) && !ported.includes(n) ? `${P}-${n}` : skillName(n));
  const names = [...ported, ...agents.filter((a) => !ported.includes(a))];
  const any = alt(names);
  const hyphenated = alt(names.filter((n) => n.includes("-")));
  const excluded = alt(EXCLUDED_SKILLS);
  const allSkills = alt(model.skills);

  const isSkillMd = /^skills\/[^/]+\/SKILL\.md$/.test(fromUp) && fromP !== null && !fromP.startsWith(`${P}-principles/`);
  const isAgent = /^agents\/[^/]+\.md$/.test(fromUp);
  const newName = isSkillMd ? posix.dirname(fromP) : isAgent ? posix.basename(fromP, ".md") : null;

  const isMarkdown = fromUp.endsWith(".md");
  const lines = text.split("\n");
  let inFrontmatter = isMarkdown && lines[0] === "---";
  return lines
    .map((line, i) => {
      if (inFrontmatter && i > 0 && line === "---") inFrontmatter = false;
      if (inFrontmatter && i > 0 && /^name:\s/.test(line)) {
        return newName ? `name: ${newName}` : line;
      }

      const held = [];
      const hold = (s) => `\x00${held.push(s) - 1}\x00`;
      for (const k of KEEP_LITERALS) line = line.split(k).join(hold(k));
      line = line.replace(/https?:\/\/[^\s<>()[\]"'`]+/g, (u) => hold(u));

      // Rule 4: links, then plain-text paths.
      const link = (t) => {
        const r = repointLink(model, fromUp, fromP, t);
        return hold(r ?? t);
      };
      if (isMarkdown) {
        line = line.replace(/(\]\()([^)\s]+)/g, (_, a, t) => a + link(t));
        line = line.replace(/^(\s*\[[^\]]+\]:\s+)(\S+)/, (_, a, t) => a + link(t));
        line = line.replace(/(\bsrc=["'])([^"']+)/g, (_, a, t) => a + link(t));
      }
      line = line.replace(
        new RegExp(`(?<![\\w.-])pstack/((?:skills|agents|docs/guide)(?:/[\\w.<>-]+)*/?)`, "g"),
        (whole, rest) => {
          const trailing = rest.endsWith("/");
          const mapped = mapPath(model, rest.replace(/\/$/, ""));
          if (mapped === null) return hold(whole);
          return hold([`skills/${P}`, mapped].filter(Boolean).join("/") + (trailing ? "/" : ""));
        },
      );
      line = line.replace(
        new RegExp(`(?<![\\w./-])skills/(${allSkills})((?:/[\\w.-]+)*)(?![\\w-])`, "g"),
        (whole, s, rest) => {
          const mapped = mapPath(model, `skills/${s}${rest}`);
          return hold(mapped === null ? whole : `skills/${P}/${mapped}`);
        },
      );
      line = line.replace(new RegExp(`(?<=\\.\\./)(${allSkills})(?=/)`, "g"), (s) => {
        const mapped = mapPath(model, `skills/${s}`);
        return mapped === null || mapped.endsWith(".md") ? s : hold(mapped);
      });

      // Rule 6: unported skill names stay verbatim.
      line = line.replace(new RegExp(`(?<![\\w-])(${excluded})(?![\\w-])`, "g"), (s) => hold(s));

      // Rule 5: skill and agent names.
      line = line.replace(
        new RegExp(`(?<![^\\s(\\[\`"'])/(${any})(?![\\w/-])`, "g"),
        (_, n) => `/${nameOf(n)}`,
      );
      line = line.replace(new RegExp(`\`(${any})\``, "g"), (_, n) => `\`${nameOf(n)}\``);
      line = line.replace(new RegExp(`\\*\\*(${any})\\*\\*`, "g"), (_, n) => `**${nameOf(n)}**`);
      line = line.replace(
        new RegExp(`(?<![\\w/#.-])(${hyphenated})(?![\\w-])`, "g"),
        (_, n) => nameOf(n),
      );

      // Rule 7: any pstack left.
      line = line.replace(/(?<![A-Za-z])pstack/gi, (m) => caseLike(m, P));

      while (/\x00\d+\x00/.test(line)) line = line.replace(/\x00(\d+)\x00/g, (_, n) => held[Number(n)]);
      return line;
    })
    .join("\n");
}

function isBinary(file, buf) {
  if (BINARY_EXTENSIONS.has(path.extname(file).toLowerCase())) return true;
  return buf.subarray(0, 8000).includes(0);
}

export function render(upstreamDir, outDir) {
  const model = buildModel(upstreamDir);
  const files = walk(upstreamDir).filter((f) => /^(skills|agents|docs\/guide)\//.test(f));
  const written = [];
  for (const up of files.sort()) {
    const dest = mapPath(model, up);
    if (dest === null) continue;
    const buf = fs.readFileSync(path.join(upstreamDir, up));
    const out = path.join(outDir, dest);
    fs.mkdirSync(path.dirname(out), { recursive: true });
    if (isBinary(up, buf)) fs.writeFileSync(out, buf);
    else fs.writeFileSync(out, renameText(model, up, dest, buf.toString("utf8")));
    fs.chmodSync(out, fs.statSync(path.join(upstreamDir, up)).mode & 0o777);
    written.push(dest);
  }
  return written;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const [upstreamDir, outDir] = process.argv.slice(2);
  if (!upstreamDir || !outDir) {
    console.error("usage: render.mjs <upstream-pstack-dir> <out-dir>");
    process.exit(2);
  }
  if (fs.existsSync(outDir)) {
    console.error(`render.mjs: ${outDir} already exists`);
    process.exit(2);
  }
  fs.mkdirSync(outDir, { recursive: true });
  render(upstreamDir, outDir);
}
