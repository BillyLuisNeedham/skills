import { copyFileSync, mkdirSync, mkdtempSync, rmSync, utimesSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { main, parseSession, readSession, slugFor } from "./transcript";

const fixtures = join(import.meta.dir, "fixtures");
const id = "5e2fa9b9-0d9e-4962-bd00-276f6ce5afff";
const agent = "a1b2c3d4e5f600001";
const cwd = "/home/user/proj";
let home: string;
let dir: string;
const env = () => ({ home, cwd, sessionId: id });
const run = (...argv: string[]) => main(argv, env());

beforeAll(() => {
	home = mkdtempSync(join(tmpdir(), "transcript-test-"));
	dir = join(home, ".claude", "projects", slugFor(cwd));
	mkdirSync(join(dir, id, "subagents"), { recursive: true });
	copyFileSync(join(fixtures, "session.jsonl"), join(dir, `${id}.jsonl`));
	copyFileSync(join(fixtures, "subagent.jsonl"), join(dir, id, "subagents", `agent-${agent}.jsonl`));
	copyFileSync(join(fixtures, "subagent.meta.json"), join(dir, id, "subagents", `agent-${agent}.meta.json`));
	const older = join(dir, "0a000000-0000-4000-8000-000000000000.jsonl");
	writeFileSync(
		older,
		`${JSON.stringify({ type: "user", message: { role: "user", content: "Rename the config loader." }, timestamp: "2026-10-01T09:00:00.000Z", cwd })}\n`,
	);
	const tenDaysAgo = Date.now() / 1000 - 10 * 86400;
	utimesSync(older, tenDaysAgo, tenDaysAgo);
});

afterAll(() => rmSync(home, { recursive: true, force: true }));

describe("slugFor", () => {
	test("turns every non-alphanumeric character into a dash", () => {
		expect(slugFor("/home/user/repos/skills/.git/pool-worktrees/51db0f19/11")).toBe(
			"-home-user-repos-skills--git-pool-worktrees-51db0f19-11",
		);
	});
});

describe("parseSession", () => {
	const session = readSession(join(fixtures, "session.jsonl"));

	test("reads the session metadata", () => {
		expect(session.cwd).toBe(cwd);
		expect(session.branch).toBe("feature/list-flag");
		expect(session.title).toBe("Add a --list flag to the CLI");
		expect(session.started).toBe("2026-10-16T22:50:02.467Z");
		expect(session.ended).toBe("2026-10-16T22:51:03.768Z");
	});

	test("splits turns at prompts, commands, notifications and compact summaries", () => {
		expect(session.turns.map((turn) => turn.kind)).toEqual(["prompt", "notification", "command", "summary", "prompt"]);
		expect(session.turns.map((turn) => turn.n)).toEqual([1, 2, 3, 4, 5]);
	});

	test("drops system reminders and meta messages from the prompt", () => {
		expect(session.turns[0].text).toBe("Add a --list flag to the CLI that prints every skill name.");
		expect(JSON.stringify(session)).not.toContain("Skill body the reader drops");
		expect(JSON.stringify(session)).not.toContain("Injected context");
	});

	test("renders a command as its slash form", () => {
		expect(session.turns[2].text).toBe("/simplify src/cli.ts");
	});

	test("pairs every tool call with its result and summary", () => {
		const tools = session.turns[0].steps.flatMap((s) => (s.kind === "tool" ? [s.tool] : []));
		expect(tools.map((t) => `${t.name} ${t.summary}`)).toEqual([
			"Read /home/user/proj/src/cli.ts",
			"Agent Explore: Find skill loader",
			"Bash bun test echo done",
			"Edit /home/user/proj/src/cli.ts",
		]);
		expect(tools[2].result).toEqual({ error: true, text: "error: 1 test failed\nexpected 2, got 1" });
		expect(tools[1].result?.text).toContain("agentId: a1b2c3d4e5f600001");
	});

	test("puts assistant steps before any prompt into an empty opening turn", () => {
		const raw = JSON.stringify({ type: "assistant", timestamp: "t", message: { content: [{ type: "text", text: "hi" }] } });
		const parsed = parseSession(raw, "/x/abc.jsonl");
		expect(parsed.turns).toHaveLength(1);
		expect(parsed.turns[0]).toMatchObject({ kind: "prompt", text: "", steps: [{ kind: "text", text: "hi" }] });
	});

	test("skips lines that are not JSON", () => {
		expect(parseSession("not json\n\n", "/x/abc.jsonl").turns).toEqual([]);
	});
});

describe("dir", () => {
	test("prints the project's transcript dir", () => {
		expect(run("dir").out).toBe(dir);
		expect(run("dir", "/other/place").out).toBe(join(home, ".claude", "projects", "-other-place"));
	});
});

describe("list", () => {
	test("lists sessions newest first with title and turn count", () => {
		const rows = JSON.parse(run("list", "--json").out);
		expect(rows.map((r: { id: string }) => r.id)).toEqual([id, "0a000000-0000-4000-8000-000000000000"]);
		expect(rows[0]).toMatchObject({ turns: 5, title: "Add a --list flag to the CLI" });
		expect(rows[1].title).toBe("Rename the config loader.");
	});

	test("--since drops old sessions and --grep filters on content", () => {
		expect(JSON.parse(run("list", "--since", "7d", "--json").out)).toHaveLength(1);
		const hits = JSON.parse(run("list", "--grep", "config loader", "--json").out);
		expect(hits.map((r: { id: string }) => r.id)).toEqual(["0a000000-0000-4000-8000-000000000000"]);
	});

	test("--subagents lists each session's subagents", () => {
		const out = run("list", "--subagents").out;
		expect(out.split("\n")[0]).toBe("MODIFIED\tSESSION\tTURNS\tTITLE\tPATH");
		expect(out).toContain(`  ${agent}\t\tExplore: Find skill loader`);
	});

	test("rejects a malformed --since", () => {
		expect(() => run("list", "--since", "soon")).toThrow("--since");
	});
});

describe("session refs", () => {
	test("accept an id, a prefix, a subagent id, a path and current", () => {
		for (const ref of [id, "5e2fa9b9", agent, join(dir, `${id}.jsonl`), "current"]) {
			expect(run("info", ref, "--json").code).toBe(0);
		}
		expect(JSON.parse(run("info", agent, "--json").out).id).toBe(agent);
	});

	test("fail clearly on an unknown session", () => {
		expect(() => run("info", "ffffffff")).toThrow("no session ffffffff");
	});

	test("current fails without CLAUDE_CODE_SESSION_ID", () => {
		expect(() => main(["info", "current"], { home, cwd })).toThrow("CLAUDE_CODE_SESSION_ID");
	});
});

describe("info", () => {
	test("gives the overview, first and last prompt, and subagents", () => {
		const info = JSON.parse(run("info", id, "--json").out);
		expect(info).toMatchObject({
			turns: 5,
			errors: 1,
			firstPrompt: "Add a --list flag to the CLI that prints every skill name.",
			lastPrompt: "Fix the failing count test, then commit.",
			tools: { Read: 1, Agent: 1, Bash: 1, Edit: 1, Skill: 1, Grep: 1, Write: 1 },
		});
		expect(info.subagents).toEqual([
			{
				id: agent,
				path: join(dir, id, "subagents", `agent-${agent}.jsonl`),
				type: "Explore",
				description: "Find skill loader",
			},
		]);
	});
});

describe("show", () => {
	test("prints turns with tool lines and errors inline", () => {
		const out = run("show", id).out;
		expect(out).toContain("## Turn 1 · 2026-10-16T22:50:02.467Z · prompt");
		expect(out).toContain("- Bash bun test echo done [error]\n    error: 1 test failed");
		expect(out).toContain("assistant: Fixed and committed as 4dc951e.");
		expect(out).not.toContain("thinking:");
		expect(out).not.toContain("File created successfully");
	});

	test("--thinking and --full add thinking and every result", () => {
		const out = run("show", id, "--thinking", "--full").out;
		expect(out).toContain("thinking: Read the CLI entry point first.");
		expect(out).toContain("File created successfully");
	});

	test("--tail, --head, --turn and --grep select turns", () => {
		const turns = (...args: string[]) => JSON.parse(run("show", id, "--json", ...args).out).turns.map((t: { n: number }) => t.n);
		expect(turns("--tail", "2")).toEqual([4, 5]);
		expect(turns("--head", "1")).toEqual([1]);
		expect(turns("--turn", "3")).toEqual([3]);
		expect(turns("--grep", "count test")).toEqual([4, 5]);
	});

	test("reads a subagent transcript", () => {
		const out = run("show", agent).out;
		expect(out).toContain("Find where skills are loaded.");
		expect(out).toContain("- Glob src/**/*.ts in /home/user/proj");
	});
});

describe("files", () => {
	test("lists files and skills the session touched", () => {
		expect(run("files", id).out.split("\n")).toEqual([
			"TOOL\tCOUNT\tTARGET",
			"Read\t1\t/home/user/proj/src/cli.ts",
			"Edit\t1\t/home/user/proj/src/cli.ts",
			"Skill\t1\tsimplify",
			"Grep\t1\t/home/user/proj/test",
			"Write\t1\t/home/user/proj/test/count.test.ts",
		]);
	});
});

describe("last-chat", () => {
	test("finds the newest session that ran in the path", () => {
		const [epoch, path] = run("last-chat", cwd).out.split("\t");
		expect(Number(epoch)).toBeGreaterThan(0);
		expect([join(dir, `${id}.jsonl`), join(dir, id, "subagents", `agent-${agent}.jsonl`)]).toContain(path);
	});

	test("finds a session in the main project that touched the path", () => {
		const found = JSON.parse(main(["last-chat", "/home/user/proj/src", "--project", cwd, "--json"], env()).out);
		expect(found.path).toContain(dir);
		expect(main(["last-chat", "/nowhere"], env()).out).toBe("");
	});
});

describe("cli", () => {
	test("runs under bun and prints usage", () => {
		const result = spawnSync("bun", [join(import.meta.dir, "transcript.ts"), "--help"], { encoding: "utf8" });
		expect(result.status).toBe(0);
		expect(result.stdout).toContain("Usage: bun transcript.ts <command>");
	});

	test("exits 1 with a message on an unknown command", () => {
		const result = spawnSync("bun", [join(import.meta.dir, "transcript.ts"), "bogus"], { encoding: "utf8" });
		expect(result.status).toBe(1);
		expect(result.stderr).toContain("unknown command: bogus");
	});
});
