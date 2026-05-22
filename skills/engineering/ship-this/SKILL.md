---
name: ship-this
description: Ship the current working copy end-to-end with zero hand-holding. Branches if needed, commits, pushes, opens a PR against the right base (from `docs/agents/git-flow.md`, or `main` if absent), runs a CodeRabbit review + autofix loop, waits for CI, and squash-merges. Use when ad-hoc changes are ready and the user says "ship it" / "/ship-this".
---

# Ship This

Take whatever is in the working copy and get it merged, end-to-end. This is the **ticket-free** sibling of [`/ship-ticket`](../ship-ticket/SKILL.md). If the work is tied to an Exponential Ticket, point the user at `/ship-ticket` instead — that path links the Ticket and transitions it to `QA`.

## Usage

```
/ship-this [--no-merge] [--no-review] [--skip-checks] [--base <branch>]
```

- `--no-merge`: stop at PR-ready. Don't auto-merge.
- `--no-review`: skip the CodeRabbit review + autofix loop.
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

Try CodeRabbit first; fall back to `/pr-review` if it's not usable here. CodeRabbit is great when it's set up and has credits, but it's a paid GitHub App with rate limits and not every repo has it.

**Probe for CodeRabbit, in this order — first hit decides:**

1. **Skill loaded?** If `coderabbit-code-review` isn't in the available-skills list this session, skip CodeRabbit. Fall back.
2. **Config file present?** If `.coderabbit.yaml`, `.coderabbit.yml`, or `coderabbit.yaml` exists at the repo root, treat that as intentional opt-in — use CodeRabbit.
3. **Past activity on the repo?** Otherwise, check for prior CodeRabbit reviews:
   ```bash
   gh api "repos/{owner}/{repo}/pulls?state=all&per_page=20" \
     --jq '[.[].user.login] + [.[].requested_reviewers[]?.login // empty]' \
     2>/dev/null | grep -q 'coderabbitai'
   ```
   Or:
   ```bash
   gh pr list --state all --limit 20 --json comments \
     --jq '[.[].comments[]?.author.login] | map(select(. == "coderabbitai")) | length' \
     2>/dev/null
   ```
   Non-zero hit → use CodeRabbit. Zero → fall back.
4. **Tied:** if you can't decide, ask the user once via `AskUserQuestion`: *"Use CodeRabbit for this review, or fall back to /pr-review?"* Don't ask on every invocation — only when the heuristic is ambiguous.

#### 7b. CodeRabbit path

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

#### 7c. `/pr-review` fallback path

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

## Failure modes

- **Pre-ship check failure** — refuse to push. Fix and re-invoke, or `--skip-checks`.
- **Push rejected** — remote has divergent history. Stop. The user resolves manually; this skill doesn't force-push or rebase silently.
- **PR exists in draft** — leave draft state alone; don't promote it. The user can `gh pr ready` themselves.
- **CodeRabbit unavailable or out of credits** — fall back to `/pr-review` automatically (see step 7a). If `/pr-review` is also unavailable, warn and continue.
- **CI red** — don't merge. Surface the failing check.
- **Required reviewers not satisfied** — enable auto-merge instead of merging directly. Tell the user.
- **`docs/agents/git-flow.md` missing** — warn, default to the repo's default branch, recommend `/setup-git-flow`.

## What this skill does NOT do

- Link to an Exponential Ticket. Use [`/ship-ticket`](../ship-ticket/SKILL.md) for ticket-linked work.
- Force-push or rewrite history. Ever.
- Run on non-GitHub remotes (GitLab/Bitbucket). GitHub Actions + `gh` only.
- Choose between squash / merge-commit / rebase. Always squash-merges.
- Override branch protection. If reviews are required, it enables auto-merge — it doesn't bypass policy.
