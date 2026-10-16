#!/usr/bin/env bun
// Read Claude Code session transcripts from ~/.claude/projects/<slug>/ and
// print them as turns: one human prompt (or command, notification, compact
// summary) and the assistant steps that answered it.
//
// Usage: bun transcript.ts <command> [args] [options]
//   dir [path]                 the transcript dir for a project path (default cwd)
//   list                       sessions in the project, newest first
//   info <session>             metadata overview, first and last prompt, subagents
//   show <session>             the turns
//   files <session>            files and skills the session touched
//   last-chat <path>           newest session that ran in or touched <path>
//
// <session> is a session id (or a unique prefix), a subagent id, a .jsonl path,
// or "current" for $CLAUDE_CODE_SESSION_ID.
//
// Options:
//   --project <path>   project whose transcripts to read (default cwd)
//   --limit <n>        list: at most n sessions (default 20)
//   --since <age>      list: only sessions modified within <age>, e.g. 7d, 36h
//   --grep <regex>     list: sessions whose raw transcript matches; show: turns that match
//   --subagents        list: include each session's subagents
//   --head <n>         show: the first n turns
//   --tail <n>         show: the last n turns
//   --turn <n>         show: one turn by number
//   --thinking         show: include thinking blocks
//   --full             show: no clipping, and every tool result
//   --json             machine-readable output

import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import { parseArgs } from "node:util";

export type ToolCall = {
	id: string;
	name: string;
	input: Record<string, unknown>;
	summary: string;
	result?: { error: boolean; text: string };
};

export type Step =
	| { kind: "text"; at: string; text: string }
	| { kind: "thinking"; at: string; text: string }
	| { kind: "tool"; at: string; tool: ToolCall };

export type TurnKind = "prompt" | "command" | "notification" | "summary";

export type Turn = { n: number; at: string; kind: TurnKind; text: string; steps: Step[] };

export type Session = {
	id: string;
	path: string;
	cwd: string;
	branch: string;
	title: string;
	started: string;
	ended: string;
	turns: Turn[];
};

export type Subagent = { id: string; path: string; type: string; description: string };

type Env = { home: string; cwd: string; sessionId?: string };

const defaultEnv = (): Env => ({
	home: process.env.HOME ?? "",
	cwd: process.cwd(),
	sessionId: process.env.CLAUDE_CODE_SESSION_ID,
});

export function slugFor(path: string): string {
	return resolve(path).replace(/[^A-Za-z0-9]/g, "-");
}

export function projectDir(project: string, env: Env = defaultEnv()): string {
	return join(env.home, ".claude", "projects", slugFor(resolve(env.cwd, project)));
}

function jsonlFiles(dir: string, recursive: boolean): string[] {
	if (!existsSync(dir)) return [];
	const out: string[] = [];
	for (const entry of readdirSync(dir, { withFileTypes: true })) {
		const path = join(dir, entry.name);
		if (entry.isFile() && entry.name.endsWith(".jsonl")) out.push(path);
		else if (recursive && entry.isDirectory()) out.push(...jsonlFiles(path, true));
	}
	return out;
}

const mtime = (path: string) => statSync(path).mtimeMs;

const byNewest = (paths: string[]) => paths.sort((a, b) => mtime(b) - mtime(a));

export function resolveSession(ref: string, project: string, env: Env = defaultEnv()): string {
	if (ref === "current") {
		if (!env.sessionId) throw new Error("CLAUDE_CODE_SESSION_ID is not set; pass a session id or path");
		ref = env.sessionId;
	}
	if (ref.endsWith(".jsonl") || ref.includes("/")) {
		const path = resolve(env.cwd, ref);
		if (existsSync(path)) return path;
		throw new Error(`no transcript at ${path}`);
	}
	const dir = projectDir(project, env);
	const matches = jsonlFiles(dir, true).filter((path) => {
		const name = basename(path, ".jsonl");
		return name.startsWith(ref) || name.startsWith(`agent-${ref}`);
	});
	if (matches.length === 1) return matches[0];
	if (matches.length === 0) throw new Error(`no session ${ref} under ${dir}`);
	const exact = matches.find((path) => basename(path, ".jsonl") === ref);
	if (exact) return exact;
	throw new Error(`session prefix ${ref} is ambiguous under ${dir}:\n${matches.join("\n")}`);
}

const clip = (text: string, max: number) =>
	max > 0 && text.length > max ? `${text.slice(0, max)} [+${text.length - max} chars]` : text;

const oneLine = (text: string) => text.replace(/\s+/g, " ").trim();

function summarize(name: string, input: Record<string, unknown>): string {
	const s = (key: string) => (typeof input[key] === "string" ? (input[key] as string) : "");
	switch (name) {
		case "Read":
		case "Write":
		case "Edit":
		case "NotebookEdit":
			return s("file_path") || s("notebook_path");
		case "Bash":
			return clip(oneLine(s("command")), 160);
		case "Grep":
		case "Glob":
			return [s("pattern"), s("path")].filter(Boolean).join(" in ");
		case "Skill":
			return [s("skill"), s("args")].filter(Boolean).join(" ");
		case "Agent":
		case "Task":
			return [s("subagent_type") || "general-purpose", s("description")].filter(Boolean).join(": ");
		case "WebFetch":
			return s("url");
		case "WebSearch":
			return s("query");
	}
	const first = Object.values(input).find((value) => typeof value === "string") as string | undefined;
	return clip(oneLine(first ?? ""), 160);
}

function resultText(content: unknown): string {
	if (typeof content === "string") return content;
	if (Array.isArray(content))
		return content.map((block) => (block?.type === "text" ? block.text : `[${block?.type}]`)).join("\n");
	return "";
}

const stripReminders = (text: string) =>
	text.replace(/<system-reminder>[\s\S]*?<\/system-reminder>/g, "").trim();

function classify(text: string): { kind: TurnKind; text: string } | null {
	const command = text.match(/<command-name>([^<]*)<\/command-name>/);
	if (command) {
		const args = text.match(/<command-args>([\s\S]*?)<\/command-args>/)?.[1].trim() ?? "";
		return { kind: "command", text: [command[1].trim(), args].filter(Boolean).join(" ") };
	}
	if (text.startsWith("<task-notification>")) return { kind: "notification", text };
	if (text.startsWith("<local-command-")) return null;
	const stripped = stripReminders(text);
	return stripped ? { kind: "prompt", text: stripped } : null;
}

export function parseSession(raw: string, path: string): Session {
	const session: Session = {
		id: basename(path, ".jsonl").replace(/^agent-/, ""),
		path,
		cwd: "",
		branch: "",
		title: "",
		started: "",
		ended: "",
		turns: [],
	};
	const pending = new Map<string, ToolCall>();
	let turn: Turn | undefined;
	const open = (at: string, kind: TurnKind, text: string) => {
		turn = { n: session.turns.length + 1, at, kind, text, steps: [] };
		session.turns.push(turn);
	};
	const step = (s: Step) => {
		if (!turn) open(s.at, "prompt", "");
		turn!.steps.push(s);
	};

	for (const line of raw.split("\n")) {
		if (!line.trim()) continue;
		let record: any;
		try {
			record = JSON.parse(line);
		} catch {
			continue;
		}
		if (record.type === "ai-title" && record.aiTitle) session.title = record.aiTitle;
		if (record.type !== "user" && record.type !== "assistant") continue;
		const at: string = record.timestamp ?? "";
		session.cwd ||= record.cwd ?? "";
		session.branch ||= record.gitBranch ?? "";
		session.started ||= at;
		if (at) session.ended = at;
		const content = record.message?.content;

		if (record.type === "assistant") {
			for (const block of Array.isArray(content) ? content : []) {
				if (block.type === "text" && block.text?.trim()) step({ kind: "text", at, text: block.text });
				else if (block.type === "thinking" && block.thinking?.trim())
					step({ kind: "thinking", at, text: block.thinking });
				else if (block.type === "tool_use") {
					const input = block.input ?? {};
					const tool: ToolCall = { id: block.id, name: block.name, input, summary: summarize(block.name, input) };
					pending.set(block.id, tool);
					step({ kind: "tool", at, tool });
				}
			}
			continue;
		}

		if (record.isMeta) continue;
		if (record.isCompactSummary) {
			open(at, "summary", typeof content === "string" ? content : resultText(content));
			continue;
		}
		const blocks = typeof content === "string" ? [{ type: "text", text: content }] : Array.isArray(content) ? content : [];
		const texts: string[] = [];
		for (const block of blocks) {
			if (block.type === "tool_result") {
				const tool = pending.get(block.tool_use_id);
				if (tool) tool.result = { error: block.is_error === true, text: resultText(block.content) };
			} else if (block.type === "text") texts.push(block.text ?? "");
			else if (block.type === "image") texts.push("[image]");
		}
		const prompt = texts.length ? classify(texts.join("\n")) : null;
		if (prompt) open(at, prompt.kind, prompt.text);
	}
	return session;
}

export function readSession(path: string): Session {
	return parseSession(readFileSync(path, "utf8"), path);
}

export function subagentsOf(sessionPath: string): Subagent[] {
	const dir = join(dirname(sessionPath), basename(sessionPath, ".jsonl"), "subagents");
	return byNewest(jsonlFiles(dir, false)).map((path) => {
		const metaPath = path.replace(/\.jsonl$/, ".meta.json");
		const meta = existsSync(metaPath) ? JSON.parse(readFileSync(metaPath, "utf8")) : {};
		return {
			id: basename(path, ".jsonl").replace(/^agent-/, ""),
			path,
			type: meta.agentType ?? "",
			description: meta.description ?? "",
		};
	});
}

const parseAge = (age: string): number => {
	const match = age.match(/^(\d+)([mhd])$/);
	if (!match) throw new Error(`--since wants a number and m, h or d, like 7d; got ${age}`);
	return Number(match[1]) * { m: 60_000, h: 3_600_000, d: 86_400_000 }[match[2] as "m" | "h" | "d"];
};

export type Listing = {
	modified: string;
	id: string;
	turns: number;
	title: string;
	path: string;
	subagents?: Subagent[];
};

export function listSessions(
	project: string,
	opts: { limit?: number; since?: string; grep?: string; subagents?: boolean },
	env: Env = defaultEnv(),
	now = Date.now(),
): Listing[] {
	let paths = byNewest(jsonlFiles(projectDir(project, env), false));
	if (opts.since) {
		const cutoff = now - parseAge(opts.since);
		paths = paths.filter((path) => mtime(path) >= cutoff);
	}
	if (opts.grep) {
		const re = new RegExp(opts.grep, "i");
		paths = paths.filter((path) => re.test(readFileSync(path, "utf8")));
	}
	return paths.slice(0, opts.limit ?? 20).map((path) => {
		const session = readSession(path);
		const first = session.turns.find((turn) => turn.kind === "prompt")?.text ?? "";
		return {
			modified: new Date(mtime(path)).toISOString(),
			id: session.id,
			turns: session.turns.length,
			title: session.title || clip(oneLine(first), 80),
			path,
			...(opts.subagents ? { subagents: subagentsOf(path) } : {}),
		};
	});
}

export function sessionInfo(session: Session) {
	const tools: Record<string, number> = {};
	let errors = 0;
	for (const turn of session.turns)
		for (const s of turn.steps)
			if (s.kind === "tool") {
				tools[s.tool.name] = (tools[s.tool.name] ?? 0) + 1;
				if (s.tool.result?.error) errors++;
			}
	const prompts = session.turns.filter((turn) => turn.kind === "prompt" || turn.kind === "command");
	return {
		id: session.id,
		path: session.path,
		cwd: session.cwd,
		branch: session.branch,
		title: session.title,
		started: session.started,
		ended: session.ended,
		turns: session.turns.length,
		tools,
		errors,
		firstPrompt: prompts[0]?.text ?? "",
		lastPrompt: prompts.at(-1)?.text ?? "",
		subagents: subagentsOf(session.path),
	};
}

const fileTools = new Set(["Read", "Write", "Edit", "NotebookEdit", "Grep", "Glob", "Skill"]);

export function touchedFiles(session: Session): { tool: string; count: number; target: string }[] {
	const counts = new Map<string, { tool: string; count: number; target: string }>();
	for (const turn of session.turns)
		for (const s of turn.steps) {
			if (s.kind !== "tool" || !fileTools.has(s.tool.name)) continue;
			const input = s.tool.input as Record<string, string>;
			const target =
				s.tool.name === "Skill" ? input.skill : input.file_path ?? input.notebook_path ?? input.path ?? "";
			if (!target) continue;
			const key = `${s.tool.name}\t${target}`;
			const entry = counts.get(key) ?? { tool: s.tool.name, count: 0, target };
			entry.count++;
			counts.set(key, entry);
		}
	return [...counts.values()];
}

export function lastChat(path: string, main: string | undefined, env: Env = defaultEnv()) {
	const target = resolve(env.cwd, path);
	const candidates = jsonlFiles(projectDir(target, env), true);
	if (main && slugFor(resolve(env.cwd, main)) !== slugFor(target)) {
		const needle = [`${target}/`, `${target}"`];
		for (const file of jsonlFiles(projectDir(main, env), true)) {
			const raw = readFileSync(file, "utf8");
			if (needle.some((n) => raw.includes(n))) candidates.push(file);
		}
	}
	const newest = byNewest(candidates)[0];
	return newest ? { epoch: Math.floor(mtime(newest) / 1000), path: newest } : null;
}

export function selectTurns(
	turns: Turn[],
	opts: { head?: number; tail?: number; turn?: number; grep?: string },
): Turn[] {
	let out = turns;
	if (opts.turn !== undefined) out = out.filter((turn) => turn.n === opts.turn);
	if (opts.grep) {
		const re = new RegExp(opts.grep, "i");
		out = out.filter((turn) => re.test(JSON.stringify(turn)));
	}
	if (opts.head !== undefined) out = out.slice(0, opts.head);
	if (opts.tail !== undefined) out = out.slice(-opts.tail);
	return out;
}

export function renderTurns(turns: Turn[], opts: { thinking?: boolean; full?: boolean }): string {
	const max = opts.full ? 0 : 2000;
	const lines: string[] = [];
	for (const turn of turns) {
		lines.push(`## Turn ${turn.n} · ${turn.at} · ${turn.kind}`, clip(turn.text, max), "");
		for (const s of turn.steps) {
			if (s.kind === "text") lines.push(`assistant: ${clip(s.text, max)}`);
			else if (s.kind === "thinking") {
				if (opts.thinking) lines.push(`thinking: ${clip(s.text, max)}`);
			} else {
				const { name, summary, result } = s.tool;
				lines.push(`- ${name}${summary ? ` ${summary}` : ""}${result?.error ? " [error]" : ""}`);
				if (result && (result.error || opts.full))
					lines.push(...clip(result.text, opts.full ? 0 : 300).split("\n").map((l) => `    ${l}`));
			}
		}
		lines.push("");
	}
	return lines.join("\n");
}

const tsv = (rows: (string | number)[][]) => rows.map((row) => row.join("\t")).join("\n");

export function main(argv: string[], env: Env = defaultEnv()): { out: string; code: number } {
	const { values, positionals } = parseArgs({
		args: argv,
		allowPositionals: true,
		options: {
			project: { type: "string" },
			limit: { type: "string" },
			since: { type: "string" },
			grep: { type: "string" },
			subagents: { type: "boolean" },
			head: { type: "string" },
			tail: { type: "string" },
			turn: { type: "string" },
			thinking: { type: "boolean" },
			full: { type: "boolean" },
			json: { type: "boolean" },
			help: { type: "boolean", short: "h" },
		},
	});
	const [command, arg] = positionals;
	const project = values.project ?? env.cwd;
	const num = (value?: string) => (value === undefined ? undefined : Number(value));
	const json = (value: unknown) => ({ out: JSON.stringify(value, null, 2), code: 0 });
	const need = (what: string) => {
		if (!arg) throw new Error(`${command} needs ${what}`);
		return arg;
	};

	switch (command) {
		case "dir":
			return { out: projectDir(arg ?? project, env), code: 0 };
		case "list": {
			const rows = listSessions(
				project,
				{ limit: num(values.limit), since: values.since, grep: values.grep, subagents: values.subagents },
				env,
			);
			if (values.json) return json(rows);
			const lines: (string | number)[][] = [["MODIFIED", "SESSION", "TURNS", "TITLE", "PATH"]];
			for (const row of rows) {
				lines.push([row.modified, row.id, row.turns, row.title, row.path]);
				for (const sub of row.subagents ?? [])
					lines.push(["", `  ${sub.id}`, "", `${sub.type}: ${sub.description}`, sub.path]);
			}
			return { out: tsv(lines), code: 0 };
		}
		case "info": {
			const info = sessionInfo(readSession(resolveSession(need("a session"), project, env)));
			if (values.json) return json(info);
			const tools = Object.entries(info.tools).map(([name, count]) => `${name} ${count}`).join(", ");
			return {
				out: [
					`session: ${info.id}`,
					`path: ${info.path}`,
					`title: ${info.title}`,
					`cwd: ${info.cwd}`,
					`branch: ${info.branch}`,
					`span: ${info.started} to ${info.ended}`,
					`turns: ${info.turns}`,
					`tools: ${tools || "none"} (${info.errors} errors)`,
					`first prompt: ${clip(oneLine(info.firstPrompt), 300)}`,
					`last prompt: ${clip(oneLine(info.lastPrompt), 300)}`,
					`subagents: ${info.subagents.length}`,
					...info.subagents.map((sub) => `  ${sub.id}\t${sub.type}: ${sub.description}\t${sub.path}`),
				].join("\n"),
				code: 0,
			};
		}
		case "show": {
			const session = readSession(resolveSession(need("a session"), project, env));
			const turns = selectTurns(session.turns, {
				head: num(values.head),
				tail: num(values.tail),
				turn: num(values.turn),
				grep: values.grep,
			});
			if (values.json) return json({ ...session, turns });
			const header = `# ${session.title || session.id}\nsession ${session.id} · ${session.cwd} · ${session.branch} · ${session.turns.length} turns\n`;
			return { out: header + "\n" + renderTurns(turns, values), code: 0 };
		}
		case "files": {
			const rows = touchedFiles(readSession(resolveSession(need("a session"), project, env)));
			if (values.json) return json(rows);
			return { out: tsv([["TOOL", "COUNT", "TARGET"], ...rows.map((r) => [r.tool, r.count, r.target])]), code: 0 };
		}
		case "last-chat": {
			const found = lastChat(need("a path"), values.project, env);
			if (values.json) return json(found);
			return { out: found ? `${found.epoch}\t${found.path}` : "", code: 0 };
		}
		case undefined:
		case "help":
			return { out: usage(), code: values.help || command === "help" ? 0 : 2 };
	}
	throw new Error(`unknown command: ${command}\n\n${usage()}`);
}

function usage(): string {
	const lines = readFileSync(import.meta.path, "utf8").split("\n");
	const start = lines.findIndex((line) => line.startsWith("// Usage"));
	const end = lines.findIndex((line, i) => i > start && !line.startsWith("//"));
	return lines.slice(start, end).map((line) => line.replace(/^\/\/ ?/, "")).join("\n");
}

if (import.meta.main) {
	try {
		const { out, code } = main(process.argv.slice(2));
		if (out) console.log(out);
		process.exit(code);
	} catch (error) {
		console.error(`transcript: ${(error as Error).message}`);
		process.exit(1);
	}
}
