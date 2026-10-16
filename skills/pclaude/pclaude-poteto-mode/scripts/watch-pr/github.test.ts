import { describe, expect, it } from "bun:test";
import {
  ChecksUnavailable,
  WatcherQueryError,
  buildReviewThreads,
  mapRollupNode,
  orderStack,
  parseFastCheck,
  parsePullRequest,
  PCLAUDE_MARKER,
  parseConversationPage,
  parseReviewThreadPage,
  resolveChecks,
  resolveContext,
  resolveReviewThreads,
  selectNewComments,
} from "./github.ts";
import {
  fakeReader,
  failedCheck,
  passingCheck,
  pendingCheck,
} from "./fakes.test-helper.ts";
import { parsePrNumber } from "./types.ts";

const context = {
  owner: "owner",
  repo: "repo",
  number: parsePrNumber(42),
};

describe("checks fallback chain", () => {
  it("uses a non-empty fast-path result without a rollup query", async () => {
    const reader = fakeReader({
      fastPath: { kind: "checks", checks: [passingCheck("fast")] },
    });
    const read = await resolveChecks(reader, context);
    expect(read.source).toBe("gh-pr-checks");
    expect(read.checks.map((check) => check.name)).toEqual(["fast"]);
    expect(reader.calls).toEqual(["checksFastPath"]);
  });

  it("paginates GraphQL when the fast path is unusable", async () => {
    const reader = fakeReader({
      fastPath: { kind: "unusable", exitCode: 8, stderr: "" },
      rollupPages: [
        { checks: [passingCheck("first")], endCursor: "next" },
        { checks: [failedCheck("second")], endCursor: null },
      ],
    });
    const read = await resolveChecks(reader, context);
    expect(read.source).toBe("graphql-rollup");
    expect(read.checks.map((check) => check.name)).toEqual(["first", "second"]);
    expect(reader.calls).toEqual([
      "checksFastPath",
      "checkRollupPage:null",
      "checkRollupPage:next",
    ]);
  });

  it("falls back when valid fast-path JSON represented an empty list", async () => {
    const reader = fakeReader({
      fastPath: { kind: "checks", checks: [] },
      rollupPages: [{ checks: [pendingCheck("fallback")], endCursor: null }],
    });
    expect((await resolveChecks(reader, context)).checks[0].name).toBe(
      "fallback"
    );
    expect(reader.calls).toEqual(["checksFastPath", "checkRollupPage:null"]);
  });

  it("fails closed when both paths are empty", async () => {
    const reader = fakeReader({
      fastPath: {
        kind: "unusable",
        exitCode: 8,
        stderr: "credential cannot read checks",
      },
    });
    await expect(resolveChecks(reader, context)).rejects.toBeInstanceOf(
      ChecksUnavailable
    );
    expect(reader.calls).toEqual(["checksFastPath", "checkRollupPage:null"]);
  });
});

describe("rollup node mapping", () => {
  it("maps terminal and non-terminal CheckRun states fail closed", () => {
    const cases = [
      ["IN_PROGRESS", null, "pending", "PENDING"],
      ["COMPLETED", "SUCCESS", "passed", "SUCCESS"],
      ["COMPLETED", "NEUTRAL", "skipped", "NEUTRAL"],
      ["COMPLETED", "SKIPPED", "skipped", "SKIPPED"],
      ["COMPLETED", "ACTION_REQUIRED", "failed", "ACTION_REQUIRED"],
      ["COMPLETED", "TIMED_OUT", "failed", "FAILURE"],
      ["COMPLETED", "FUTURE_VALUE", "failed", "FAILURE"],
    ] as const;
    for (const [status, conclusion, kind, reportedState] of cases) {
      expect(
        mapRollupNode({
          __typename: "CheckRun",
          name: "ci",
          status,
          conclusion,
        })
      ).toMatchObject({ kind, reportedState });
    }
  });

  it("classifies an in-progress Code Review Gate from the rollup as the gate", () => {
    expect(
      mapRollupNode({
        __typename: "CheckRun",
        name: "Code Review Gate",
        status: "IN_PROGRESS",
        conclusion: null,
      })
    ).toMatchObject({ kind: "code-review-gate" });
    expect(
      mapRollupNode({
        __typename: "StatusContext",
        context: "Code Review Gate",
        state: "PENDING",
      })
    ).toMatchObject({ kind: "code-review-gate" });
  });

  it("classifies a Code Review Gate waiting on an owner approval as the gate", () => {
    expect(
      mapRollupNode({
        __typename: "CheckRun",
        name: "Code Review Gate",
        status: "COMPLETED",
        conclusion: "ACTION_REQUIRED",
        description: "1 of 2 policies",
      })
    ).toMatchObject({
      kind: "code-review-gate",
      reportedState: "ACTION_REQUIRED",
    });
  });

  it("classifies a fast-path Code Review Gate waiting on an owner approval as the gate", () => {
    expect(
      parseFastCheck({
        name: "Code Review Gate",
        state: "ACTION_REQUIRED",
        bucket: "fail",
      })
    ).toMatchObject({
      kind: "code-review-gate",
      reportedState: "ACTION_REQUIRED",
    });
    expect(
      parseFastCheck({ name: "ci", state: "ACTION_REQUIRED", bucket: "fail" })
    ).toMatchObject({ kind: "failed", reportedState: "ACTION_REQUIRED" });
  });

  it("maps StatusContext states and drops unknown typenames", () => {
    expect(
      mapRollupNode({
        __typename: "StatusContext",
        context: "ci",
        state: "EXPECTED",
      })
    ).toMatchObject({ kind: "pending", reportedState: "PENDING" });
    expect(
      mapRollupNode({
        __typename: "StatusContext",
        context: "ci",
        state: "FUTURE_VALUE",
      })
    ).toMatchObject({ kind: "failed", reportedState: "FUTURE_VALUE" });
    expect(mapRollupNode({ __typename: "FutureNode" })).toBeNull();
  });
});

describe("closed enum parsing", () => {
  const rawPullRequest = {
    mergeable: "MERGEABLE",
    mergeStateStatus: "CLEAN",
    reviewDecision: "APPROVED",
    headRefOid: "head",
    headRefName: "feature",
    baseRefName: "main",
    state: "OPEN",
    mergedAt: null,
    isDraft: false,
  };

  it("accepts mergeStateStatus CONFLICTING", () => {
    expect(
      parsePullRequest(
        { ...rawPullRequest, mergeStateStatus: "CONFLICTING" },
        context
      ).mergeStateStatus
    ).toBe("CONFLICTING");
  });

  it("reads gh's empty reviewDecision as no decision rather than a parse failure", () => {
    expect(
      parsePullRequest({ ...rawPullRequest, reviewDecision: "" }, context)
        .reviewDecision
    ).toBeNull();
  });

  it("still rejects an unknown reviewDecision", () => {
    expect(() =>
      parsePullRequest({ ...rawPullRequest, reviewDecision: "MAYBE" }, context)
    ).toThrow(WatcherQueryError);
  });

  it("rejects unknown enum values as retryable errors carrying the raw value", () => {
    try {
      parsePullRequest(
        { ...rawPullRequest, mergeStateStatus: "FUTURE_STATE" },
        context
      );
      throw new Error("expected parser to throw");
    } catch (error) {
      expect(error).toBeInstanceOf(WatcherQueryError);
      if (!(error instanceof WatcherQueryError)) throw error;
      expect(error.failure).toMatchObject({
        kind: "missing-key",
        retryable: true,
        rawValue: '"FUTURE_STATE"',
      });
    }
  });
});

const node = (
  id: string,
  login: string | null,
  typename: "User" | "Bot",
  body: string,
  createdAt = "2026-10-01T00:00:00Z",
  reviewId: string | null = null
) => ({
  id,
  databaseId: Number(id.replace(/\D/g, "") || 0),
  url: `https://github.com/owner/repo/pull/1#${id}`,
  body,
  createdAt,
  path: "a.ts",
  line: 1,
  author: login === null ? null : { login, __typename: typename },
  pullRequestReview: reviewId === null ? null : { id: reviewId },
});
const threadResponse = (
  threads: readonly {
    readonly id: string;
    readonly isResolved: boolean;
    readonly comments: readonly ReturnType<typeof node>[];
  }[]
) => ({
  data: {
    repository: {
      pullRequest: {
        reviewThreads: {
          pageInfo: { hasNextPage: false, endCursor: null },
          nodes: threads.map((thread) => ({
            id: thread.id,
            isResolved: thread.isResolved,
            first: { nodes: thread.comments.slice(0, 1) },
            recent: { nodes: thread.comments },
          })),
        },
      },
    },
  },
});

it("counts each bot's review passes as its distinct reviews", () => {
  const response = threadResponse([
    {
      id: "one",
      isResolved: false,
      comments: [node("c1", "review-bot[bot]", "Bot", "bug", undefined, "r1")],
    },
    {
      id: "two",
      isResolved: false,
      comments: [node("c2", "review-bot", "Bot", "bug", undefined, "r2")],
    },
    {
      id: "resolved",
      isResolved: true,
      comments: [node("c3", "review-bot", "Bot", "bug", undefined, "r3")],
    },
  ]);
  const threads = buildReviewThreads(parseReviewThreadPage(response).threads);
  expect(threads.map((thread) => thread.id)).toEqual(["one", "two"]);
  expect(threads.map((thread) => thread.authorKind)).toEqual(["bot", "bot"]);
  expect(threads.map((thread) => thread.botReviewPasses)).toEqual([1, 2]);
});

it("reports a human's review thread as human, never as a bot", () => {
  const response = threadResponse([
    {
      id: "human",
      isResolved: false,
      comments: [node("c1", "billy", "User", "rename this")],
    },
    {
      id: "ghost",
      isResolved: false,
      comments: [node("c2", null, "User", "deleted account")],
    },
  ]);
  const threads = buildReviewThreads(parseReviewThreadPage(response).threads);
  expect(threads).toEqual([
    expect.objectContaining({
      id: "human",
      authorKind: "human",
      botReviewPasses: 0,
      firstComment: expect.objectContaining({ authorLogin: "billy" }),
    }),
    expect.objectContaining({ id: "ghost", authorKind: "human" }),
  ]);
});

describe("new PR comments", () => {
  const conversation = (
    source: "issue-comment" | "review",
    nodes: readonly ReturnType<typeof node>[]
  ) =>
    parseConversationPage(
      {
        data: {
          repository: {
            pullRequest: {
              items: {
                pageInfo: { hasNextPage: false, endCursor: null },
                nodes,
              },
            },
          },
        },
      },
      source
    ).comments;

  it("reports a human's conversation comment as a human comment", () => {
    const comments = selectNewComments({
      threads: [],
      conversation: conversation("issue-comment", [
        node("h1", "billy", "User", "Can you split this PR?"),
      ]),
      since: null,
    });
    expect(comments).toEqual([
      {
        id: "h1",
        databaseId: 1,
        source: "issue-comment",
        thread: null,
        url: "https://github.com/owner/repo/pull/1#h1",
        authorLogin: "billy",
        authorKind: "human",
        body: "Can you split this PR?",
        createdAt: "2026-10-01T00:00:00Z",
      },
    ]);
  });

  it("reports comments from every author, bots included, oldest first", () => {
    const comments = selectNewComments({
      threads: [],
      conversation: [
        ...conversation("issue-comment", [
          node(
            "b1",
            "coverage[bot]",
            "Bot",
            "coverage fell",
            "2026-10-03T00:00:00Z"
          ),
        ]),
        ...conversation("review", [
          node("r1", "reviewer", "User", "Looks off", "2026-10-02T00:00:00Z"),
        ]),
      ],
      since: null,
    });
    expect(
      comments.map((comment) => [
        comment.id,
        comment.authorKind,
        comment.source,
      ])
    ).toEqual([
      ["r1", "human", "review"],
      ["b1", "bot", "issue-comment"],
    ]);
  });

  it("skips empty review bodies, pclaude's own posts and anything up to the cursor", () => {
    const comments = selectNewComments({
      threads: [],
      conversation: conversation("issue-comment", [
        node("old", "billy", "User", "seen already", "2026-10-01T00:00:00Z"),
        node("empty", "billy", "User", "   ", "2026-10-05T00:00:00Z"),
        node(
          "mine",
          "billy",
          "User",
          `${PCLAUDE_MARKER}\nPASS`,
          "2026-10-05T00:00:00Z"
        ),
        node("new", "billy", "User", "one more thing", "2026-10-05T00:00:00Z"),
      ]),
      since: "2026-10-01T00:00:00Z",
    });
    expect(comments.map((comment) => comment.id)).toEqual(["new"]);
  });

  it("reports a human reply in a resolved thread but not in an open one", () => {
    const { threads } = parseReviewThreadPage(
      threadResponse([
        {
          id: "resolved",
          isResolved: true,
          comments: [
            node("t1", "review-bot", "Bot", "bug"),
            node(
              "t2",
              "billy",
              "User",
              "no, this is still wrong",
              "2026-10-04T00:00:00Z"
            ),
          ],
        },
        {
          id: "open",
          isResolved: false,
          comments: [
            node("t3", "review-bot", "Bot", "bug"),
            node("t4", "billy", "User", "agreed", "2026-10-04T00:00:00Z"),
          ],
        },
      ])
    );
    const comments = selectNewComments({
      threads,
      conversation: [],
      since: null,
    });
    expect(
      comments.map((comment) => [
        comment.id,
        comment.source,
        comment.authorKind,
      ])
    ).toEqual([["t2", "thread-reply", "human"]]);
    expect(comments[0]?.thread).toEqual({ id: "resolved", rootDatabaseId: 1 });
  });
});

describe("review thread pagination", () => {
  const thread = (id: string, resolved = false) => ({
    id,
    firstComment: {
      id: `${id}-c`,
      databaseId: null,
      url: "",
      authorLogin: "someone",
      authorKind: "human" as const,
      reviewId: null,
      body: "please fix",
      path: "a.ts",
      line: 1,
      createdAt: "now",
    },
    replies: [],
    resolved,
  });

  it("keeps walking pages until the cursor is exhausted", async () => {
    const reader = fakeReader({
      threadPages: [
        { threads: [thread("one")], endCursor: "next" },
        { threads: [thread("two")], endCursor: "last" },
        { threads: [thread("three")], endCursor: null },
      ],
    });
    const threads = await resolveReviewThreads(reader, context);
    expect(threads.map((item) => item.id)).toEqual(["one", "two", "three"]);
    expect(reader.calls).toEqual([
      "reviewThreadPage:null",
      "reviewThreadPage:next",
      "reviewThreadPage:last",
    ]);
  });

  it("sees an unresolved thread that sits past the first page", async () => {
    const reader = fakeReader({
      threadPages: [
        { threads: [thread("early", true)], endCursor: "next" },
        { threads: [thread("late")], endCursor: null },
      ],
    });
    const threads = await resolveReviewThreads(reader, context);
    expect(threads.map((item) => item.id)).toEqual(["late"]);
  });

  it("stops after a single page when the cursor is exhausted", async () => {
    const reader = fakeReader({
      threadPages: [{ threads: [thread("only")], endCursor: null }],
    });
    expect((await resolveReviewThreads(reader, context)).length).toBe(1);
    expect(reader.calls).toEqual(["reviewThreadPage:null"]);
  });

  it("counts a bot's review passes across every page", async () => {
    const bot = (id: string, reviewId: string) => ({
      id,
      firstComment: {
        id: `${id}-c`,
        databaseId: null,
        url: "",
        authorLogin: "review-bot",
        authorKind: "bot" as const,
        reviewId,
        body: "bug",
        path: "a.ts",
        line: 1,
        createdAt: "now",
      },
      replies: [],
      resolved: false,
    });
    const reader = fakeReader({
      threadPages: [
        { threads: [bot("one", "review-1")], endCursor: "next" },
        { threads: [bot("two", "review-2")], endCursor: null },
      ],
    });
    const threads = await resolveReviewThreads(reader, context);
    expect(threads.map((item) => item.botReviewPasses)).toEqual([2, 2]);
  });

  it("drops resolved threads from later pages too", async () => {
    const reader = fakeReader({
      threadPages: [
        { threads: [thread("one")], endCursor: "next" },
        { threads: [thread("two", true)], endCursor: null },
      ],
    });
    expect(
      (await resolveReviewThreads(reader, context)).map((item) => item.id)
    ).toEqual(["one"]);
  });

  it("rejects a page that omits pageInfo instead of assuming one page", async () => {
    const response = {
      data: {
        repository: {
          pullRequest: { reviewThreads: { nodes: [] } },
        },
      },
    };
    expect(() => parseReviewThreadPage(response)).toThrow(WatcherQueryError);
  });
});

describe("context and stack discovery", () => {
  it("returns a fully explicit context without any reader call", async () => {
    const reader = fakeReader();
    expect(
      await resolveContext({
        reader,
        owner: "explicit",
        repo: "repo",
        pr: context.number,
      })
    ).toEqual({ owner: "explicit", repo: "repo", number: context.number });
    expect(reader.calls).toEqual([]);
  });

  it("uses the local origin before currentPr for an explicit number", async () => {
    const reader = fakeReader({ origin: { owner: "local", repo: "checkout" } });
    expect(
      await resolveContext({
        reader,
        owner: null,
        repo: null,
        pr: context.number,
      })
    ).toEqual({ owner: "local", repo: "checkout", number: context.number });
    expect(reader.calls).toEqual(["originRepo"]);
  });

  it("orders the connected stack bottom-to-top", () => {
    const ordered = orderStack(context, [
      {
        number: parsePrNumber(41),
        headRefName: "base-feature",
        baseRefName: "main",
      },
      {
        number: context.number,
        headRefName: "feature",
        baseRefName: "base-feature",
      },
      {
        number: parsePrNumber(43),
        headRefName: "upstack",
        baseRefName: "feature",
      },
    ]);
    expect(ordered.map((item) => Number(item.number))).toEqual([41, 42, 43]);
  });
});
