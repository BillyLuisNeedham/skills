---
name: merge-pr
description: Squash-merge an Android PR, move its Jira ticket to Dev Complete, and fill the Jenkins build number into the ticket's testing notes.
disable-model-invocation: true
---

Takes one PR number or URL in `Hostelworld-ms/android-app`. Each step ends on its **done** line; stop and report to the user at any step that cannot reach it.

## 1. Preflight

`gh pr view <n> --json state,title,headRefName,baseRefName,headRefOid,mergeStateStatus,reviewDecision,statusCheckRollup`. The Jira key is in the title or the `feature/<KEY>` head branch.

Also record the PRs stacked on this one, before the merge retargets them: `gh pr list --state open --base <headRefName> --json number,headRefName`.

**Done:** state `OPEN`, `reviewDecision` `APPROVED`, `mergeStateStatus` `CLEAN`, every check `SUCCESS` or `SKIPPED`, and a Jira key in hand. Note `headRefOid`, `baseRefName` and the stacked PRs for the next steps.

## 2. Merge

Squash, with GitHub's default commit message. Use the async merge endpoint every time: it is the only route GitHub accepts for a PR in a stack, and it works for an unstacked one too.

```sh
gh api -X PUT repos/Hostelworld-ms/android-app/pulls/<n>/merge-async \
  -f merge_method=squash -f merge_action=direct_merge -f sha=<headRefOid>
```

Pinning `sha` makes GitHub cancel the merge if someone pushed after preflight. The response carries a `uuid`; poll `gh api repos/Hostelworld-ms/android-app/pulls/<n>/merge-async/<uuid>` every few seconds while `status` is `pending`.

**Done:** `status` is `merged` and `details.sha` is the merge commit.

## 3. Build number

The merge starts a Jenkins branch build on the base branch. Jenkins answers 403 to unauthenticated calls, so read the number from the GitHub commit status Jenkins posts on the merge commit:

```sh
gh api repos/Hostelworld-ms/android-app/commits/<merge sha>/statuses \
  --jq '.[] | select(.context == "continuous-integration/jenkins/branch") | .target_url'
```

The URL ends `/job/<base branch, double-encoded>/<N>/display/redirect`; `<N>` is the build number. The status appears within a minute or so of the merge, so poll every 10 seconds for up to five minutes.

**Done:** `<N>` read from a `target_url` whose job segment matches `baseRefName`.

## 4. Jira

Use the Atlassian MCP with cloud id `hostelworld.atlassian.net`.

1. **Transition.** List the ticket's transitions and apply the one named `Dev Complete`, looking the id up by name each time since it differs between projects.
2. **Build number.** Fetch the ticket's comments in **ADF**. Find the testing-notes comment: the one whose Remarks line reads `Can be tested on build # on <branch> branch`. Write the whole comment back by its `commentId` in ADF, identical except that text node now reads `build #<N>`. Edit in ADF because a markdown round trip rewrites the comment's marks and lists.

**Done:** a re-read shows status `DEV COMPLETE` and the comment's Remarks line reading `build #<N>`, every other node unchanged. When no comment carries a `build #` line, the ticket has no testing notes yet: tell the user, who can write them with `/hw-android-create-testing-notes`, and leave the comment step undone.

## 5. Report

Give the user: the merge commit, the build number with its Jenkins URL (still running at this point, so say it has not passed yet), and the new Jira status.

Then name each stacked PR from preflight. GitHub retargets them onto `baseRefName` when the merged head branch is deleted, but the squash leaves the merged commits in their history, so their diffs show this PR's changes again until rebased with `git rebase --onto origin/<baseRefName> <headRefOid> <branch>`. Offer that rebase.
