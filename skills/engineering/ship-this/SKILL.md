---
name: ship-this
description: Ship the current working copy end-to-end with zero hand-holding. Branches if needed, commits, pushes, opens a PR against the right base (from `docs/agents/git-flow.md`, or `main` if absent), waits for whichever automated reviewer the repo has (PR-Agent, CodeRabbit, or a local `/pr-review`), applies the findings, waits for CI, and squash-merges. Use when ad-hoc changes are ready and the user says "ship it" / "/ship-this".
---

# Ship This

Take whatever is in the working copy and get it merged, end-to-end. This is the **ticket-free** sibling of [`/ship-ticket`](../ship-ticket/SKILL.md). If the work is tied to an Exponential Ticket, point the user at `/ship-ticket` instead — that path links the Ticket and transitions it to `QA`.

## Usage

```
/ship-this [--no-merge] [--no-review] [--skip-checks] [--base <branch>]
```

- `--no-merge`: stop at PR-ready. Don't auto-merge.
- `--no-review`: skip the review + autofix loop.
- `--skip-checks`: bypass pre-ship checks. PR opens as **draft**, auto-merge disabled.
- `--base <branch>`: override the base branch resolved from `docs/agents/git-flow.md`.

## Prerequisites

- Inside a git repo (`git rev-parse --show-toplevel`).
- `gh` authenticated (`gh auth status`).
- Working copy has something to ship: either uncommitted changes, or commits ahead of the base branch.

## Process

### 1. Resolve the base branch

Read `docs/agents/git-flow.md` front-matter for `featureBase`.

- If the file exists → use `featureBase`.
- If the file is missing → fall back to the repo's default branch (`gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`). Warn the user and recommend `/setup-git-flow` for next time.
- If `--base` was passed → override both of the above.

Capture the resolved value as `<base>`.

### 2. Branch decision

Run `git rev-parse --abbrev-ref HEAD` to get the current branch.

**On the base branch (or trunk):**

Ask the user for a branch name, suggesting one derived from the diff:

```bash
git diff --stat HEAD
git diff --cached --stat
```

Generate a kebab-case suggestion from the most-changed file or the dominant change theme (e.g. `ship/add-ship-this-skill`). Use the `AskUserQuestion` tool with the suggestion as the first option; accept any override. Then:

```bash
git checkout -b <chosen-branch>
```

**Already on a feature branch:** use it. No new branch.

### 3. Commit working tree (three states, same as `/ship-ticket`)

Run `git status --porcelain` and `git rev-list --count <base>..HEAD` to classify:

**State A — working tree changes + zero commits ahead of `<base>`:**

Derive a commit message from the diff:

- Type: `feat` for new files, `fix` for changes to existing logic, `chore` for config/tooling, `docs` for `*.md` only. Best-effort — when ambiguous, `feat` is the default.
- Subject: one-line summary of the dominant change.

Show the message to the user via `AskUserQuestion` and let them accept or rewrite. Then:

```bash
git add -A
git commit -m "<message>"
```

**State B — clean tree + N>0 commits ahead:** no new commit. Continue.

**State C — mixed:** commit only the leftovers. Existing commits ride along unchanged. Don't rewrite history.

### 4. Pre-ship checks

If `--skip-checks` is set, **skip this section** and remember to open the PR as draft and skip auto-merge.

Discover from `package.json` scripts (top-level only):

```bash
node -e "const s=require('./package.json').scripts||{}; \
  for (const k of ['typecheck','test','lint']) if (s[k]) console.log(k)"
```

Run any present scripts in order: `typecheck`, then `test`, then `lint`. Stop on the first failure and refuse to push. Show the user:

- which check failed
- the failing output (last ~30 lines)
- that they can fix and re-run, or re-invoke with `--skip-checks` to open as draft

If `package.json` has none of those scripts, skip silently — don't invent checks. (Other ecosystems out of scope for this first cut.)

### 5. Push

```bash
git push -u origin HEAD
```

If push fails (remote has commits we don't), surface and stop. **Don't force-push.**

### 6. Open or extend the PR

```bash
gh pr view --json url,body,isDraft,baseRefName 2>/dev/null
```

**PR exists:** reuse it. Don't change its title or draft state.

**PR doesn't exist:** open one.

- Title: derived from the most recent commit subject on the branch.
- Body template:

  ````markdown
  ## What

  <bulleted summary of commit subjects on this branch, oldest first>

  ## Why

  <one-line capture of the user's intent if known from the conversation; otherwise omit this section>
  ````

- Open ready-for-review unless `--skip-checks` was used:

  ```bash
  gh pr create --base "<base>" --title "<title>" --body "<body>" [--draft]
  ```

Capture the URL from stdout. Print it.

### 7. Review + autofix loop

Skip this section entirely if `--no-review` or `--skip-checks` was passed.

#### 7a. Pick a reviewer

Three candidates, in preference order: **PR-Agent**, **CodeRabbit**, then a local **`/pr-review`**. The first two run in the repo's own CI and comment on the PR; `/pr-review` runs on your machine and reports only to the agent.

**Probe the repo — first hit decides:**

1. **PR-Agent configured?** A `.pr_agent.toml` at the repo root, or any workflow that uses the action:
   ```bash
   test -f .pr_agent.toml && echo pr-agent
   grep -rl 'qodo-ai/pr-agent' .github/workflows/ 2>/dev/null
   ```
   Either hit → PR-Agent (7b).
2. **CodeRabbit configured?** `.coderabbit.yaml`, `.coderabbit.yml`, or `coderabbit.yaml` at the repo root — treat as intentional opt-in. Requires `coderabbit-code-review` to be in the available-skills list this session; if it isn't, skip to 3. Hit → CodeRabbit (7c).
3. **Past activity on the repo?** Check who has reviewed recent PRs:
   ```bash
   gh pr list --state all --limit 20 --json comments \
     --jq '[.[].comments[]?.author.login] | group_by(.) | map({login: .[0], n: length})' \
     2>/dev/null
   ```
   `coderabbitai` present → CodeRabbit. `github-actions` present *and* a PR-Agent workflow exists → PR-Agent. Neither → 4.
4. **Nothing configured** → `/pr-review` (7d).

If both PR-Agent and CodeRabbit are set up, prefer **PR-Agent**: it's repo-owned CI, so "has the review finished?" has a definite answer (a workflow run either concluded or it didn't). CodeRabbit is a third-party App whose only signal is comment activity, and it's rate-limited on paid plans — a silent CodeRabbit is indistinguishable from a slow one.

#### 7b. PR-Agent path

PR-Agent (Qodo) reviews on every push to the PR and posts as `github-actions` — a **Reviewer Guide** comment (findings) and, when `auto_improve` is on, a **Code Suggestions** comment.

**Do not detect completion by "a new comment appeared."** Under `persistent_comment = true` — the usual config — PR-Agent *edits its existing* Reviewer Guide comment in place. Comment count and creation timestamps never move, so a naive check reads the *previous* push's review and has you fixing findings that no longer apply.

Two signals that are actually reliable, both anchored to the head SHA:

- **The PR-Agent workflow run for the current head SHA has concluded.** This is the gate. It fires whether or not the review found anything.
- **The Code Suggestions comment carries the reviewed commit** as an HTML stamp — `<!-- 275120e -->`, the short head SHA. Use this to confirm the suggestions you're reading describe the current code, *not* to decide whether to proceed: a clean review may post no suggestions comment at all, and waiting on one would hang forever.

**Wait without burning context.** Run the poll as a **background** Bash job (`run_in_background: true`) with a command that exits when the run concludes. The harness re-invokes you on exit, so you never sit in a polling loop:

```bash
PR=<pr-number>
WF=$(grep -rl 'qodo-ai/pr-agent' .github/workflows/ | head -1 | xargs -r basename)
[ -n "$WF" ] || { echo "no PR-Agent workflow in this repo"; exit 1; }
SHA=$(gh pr view "$PR" --json headRefOid --jq .headRefOid)
for _ in $(seq 60); do
  s=$(gh run list -w "$WF" -c "$SHA" --json status,conclusion \
        --jq '.[0] | "\(.status) \(.conclusion)"' 2>/dev/null)
  case "$s" in
    "completed "*) echo "review finished for $SHA: $s"; exit 0 ;;
  esac
  sleep 15
done
echo "timed out after 15m waiting for $WF on $SHA"; exit 1
```

Exit 0 → the review is in. Exit 1 (timeout) → treat PR-Agent as unavailable, fall back to `/pr-review` for this round, and don't re-arm the wait.

Then, up to **two rounds** of review → fix → push:

1. Wait, as above.
2. Read what it posted. Filter by the comment headings, not just the author — `github-actions` is every workflow in the repo, and on a busy repo most of its comments aren't the review:
   ```bash
   gh pr view "$PR" --json comments \
     --jq '.comments[] | select(.author.login=="github-actions")
           | select(.body | test("PR Reviewer Guide|PR Code Suggestions")) | .body'
   ```
   Check the Code Suggestions stamp against the current head SHA and ignore the block if it's stale.
3. **Apply with judgement, not wholesale.** The Reviewer Guide's findings — especially anything under tests or security — are worth acting on. The Code Suggestions are advisory and generated *to a fixed count* (`num_code_suggestions`, commonly 4): PR-Agent emits that many whether or not four things deserve changing, so expect filler. Take what's real, skip what isn't, and say which you skipped and why in your step-10 report.
4. Commit per finding (`fix: <one-line>`) and `git push`.
5. No commits produced → exit the loop.

Pushing fixes re-triggers PR-Agent on a new head SHA, which is exactly what round two waits on — re-read `headRefOid` each round rather than reusing the old value. Two rounds is the cap: if the reviewer is still finding new problems after two passes, something deeper is wrong and human eyes are warranted.

#### 7c. CodeRabbit path

Up to **two rounds** of review → fix → push. The cap is intentional — if CodeRabbit keeps finding new issues after two passes, something deeper is wrong and human eyes are warranted.

For each round:

1. Invoke the `coderabbit-code-review` skill against the PR.
2. **Confirm CodeRabbit actually engaged.** Poll the PR for up to 90 seconds:
   ```bash
   gh pr view <pr-number> --json reviews,comments \
     --jq '[.reviews[], .comments[]] | map(select(.author.login == "coderabbitai")) | length'
   ```
   - Count goes up → CodeRabbit posted. Continue.
   - Count stays zero after 90s → assume CodeRabbit is dead/disabled. Fall back to `/pr-review` for this round and the next (don't keep retrying CodeRabbit).
   - Latest CodeRabbit comment body matches `/limit|quota|credit|exhausted|upgrade/i` → out of credits. Fall back.
3. Invoke `coderabbit-autofix` to address findings.
4. If autofix produced commits, push:
   ```bash
   git push
   ```
5. If autofix produced no commits (no findings, or findings non-actionable), exit the loop.

#### 7d. `/pr-review` fallback path

`/pr-review` runs locally and produces a findings report to the agent — it doesn't post comments to the PR. So:

1. Invoke the `pr-review` skill scoped to the PR (or to `HEAD` vs `<base>` if that's the contract). Capture the findings report.
2. For each actionable finding, fix it directly in the working copy. Stage and commit per-finding (small, named commits — `fix: <one-line>`) so the history is reviewable.
3. Push.
4. One pass only — no second round in fallback mode. `/pr-review` is deterministic over the same diff; re-running adds noise.

If `pr-review` is also unavailable, warn the user and continue to step 8 with no review. Don't fail the whole ship.

### 8. Wait for CI

```bash
gh pr checks --watch --fail-fast
```

Run this as a **background** Bash job too (`run_in_background: true`). CI on a real repo outlasts a foreground tool call, and `--watch` blocks until it's done; backgrounding it means the harness re-invokes you when checks settle instead of the call timing out mid-run.

- All green → continue to merge.
- Any check red → surface the failing check name + log link, stop. Don't merge.
- No required checks configured → continue.

If `--no-merge` is set, skip the wait and stop here with the PR URL.

### 9. Merge

Default: squash-merge with branch deletion.

```bash
gh pr merge --squash --delete-branch
```

If branch protection forces a delay (required reviewers, status checks the user hasn't configured locally), fall back to:

```bash
gh pr merge --squash --auto --delete-branch
```

This enables auto-merge so GitHub merges as soon as the policy is satisfied. Tell the user merge is queued, not complete.

If `--skip-checks` was used, **do not merge** — the PR is draft and the user opted out of verification. Print the URL and stop.

### 10. Report

Print:

- PR URL (clickable)
- Final state: `merged` / `auto-merge queued` / `awaiting CI` / `draft, awaiting your call`
- Branch deletion status
- Anything still pending the user's attention (required reviewers, failing checks)

### 11. Hand off to `/cleanup`

Only when the final state is `merged`. The PR is on the Trunk, but the worktree is still on disk and the branch is still local — and the user has no way of knowing whether anything else is outstanding without being told.

Run the `/cleanup` skill. It tears down the worktree (or hands back the one command to do it), promotes any Exponential Tickets whose PR it can confirm merged, and closes with the **all-clear** — the explicit statement of whether anything is still in flight, and therefore whether this tab can be closed. Don't write that verdict here; `/cleanup` owns it, and it is only trustworthy because it is derived from evidence that skill gathers itself.

On any other final state — `auto-merge queued`, `awaiting CI`, `draft` — skip this. The work hasn't landed, so there is nothing to clean up and no all-clear to give. Say what the user is waiting on instead.

## Failure modes

- **Pre-ship check failure** — refuse to push. Fix and re-invoke, or `--skip-checks`.
- **Push rejected** — remote has divergent history. Stop. The user resolves manually; this skill doesn't force-push or rebase silently.
- **PR exists in draft** — leave draft state alone; don't promote it. The user can `gh pr ready` themselves.
- **CodeRabbit unavailable or out of credits** — fall back to `/pr-review` automatically (see step 7a). If `/pr-review` is also unavailable, warn and continue.
- **PR-Agent workflow never concludes** — the 15-minute wait exits non-zero. Fall back to `/pr-review` for that round; don't re-arm the wait. A workflow that fails outright (`completed failure`) still satisfies the gate — read whatever it posted, and mention the failed run in the report.
- **PR-Agent review is stale** — the Code Suggestions stamp doesn't match `headRefOid`. Something pushed after the review started. Ignore the stale block and re-wait on the new SHA (this consumes one of the two rounds).
- **CI red** — don't merge. Surface the failing check.
- **Required reviewers not satisfied** — enable auto-merge instead of merging directly. Tell the user.
- **`docs/agents/git-flow.md` missing** — warn, default to the repo's default branch, recommend `/setup-git-flow`.

## What this skill does NOT do

- Link to an Exponential Ticket. Use [`/ship-ticket`](../ship-ticket/SKILL.md) for ticket-linked work.
- Remove the worktree or delete the local branch. That's `/cleanup`, invoked at step 11 once the merge is real.
- Force-push or rewrite history. Ever.
- Run on non-GitHub remotes (GitLab/Bitbucket). GitHub Actions + `gh` only.
- Choose between squash / merge-commit / rebase. Always squash-merges.
- Override branch protection. If reviews are required, it enables auto-merge — it doesn't bypass policy.
