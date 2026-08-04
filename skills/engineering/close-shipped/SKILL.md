---
name: close-shipped
description: Sweep up after work that has already landed — remove the git worktrees whose branches merged, and promote Exponential Tickets from `QA` to `DONE` once their PR is confirmed merged. The manual stand-in for `/setup-merge-hook`.
disable-model-invocation: true
---

# Close Shipped

`/ship-ticket` leaves a Ticket in `QA` and a worktree on disk. If `/setup-merge-hook` has been run on the repo, the GitHub Action promotes `QA → DONE` when the PR merges. Where it hasn't — or where you merged by hand — nothing does, and both pile up: Tickets sit in `QA` long after they shipped, worktrees for branches deleted weeks ago still hold disk.

This is the sweep. It closes out work that has **already landed**, and nothing else.

Everything it does is gated on **evidence that the work actually merged** — a `MERGED` PR, or a branch reachable from the base. It never flips a Ticket because it looks done, and never removes a worktree because it looks stale. A `QA` Ticket with no merged PR stays in `QA`; that's the signal that something still needs a human.

## Usage

```
/close-shipped [--dry-run] [--product <slug>] [--worktrees-only | --tickets-only]
```

- `--dry-run`: survey and print the plan, change nothing. Do this first on a repo you haven't swept before.
- `--product <slug>`: override the product from `docs/agents/issue-tracker.md`.
- `--worktrees-only` / `--tickets-only`: run just one half.

## Prerequisites

- Inside a git repo (`git rev-parse --show-toplevel`).
- `gh` authenticated (`gh auth status`) — merge state is read from GitHub, not guessed.
- For the Ticket half: `exponential auth status` ok, and `docs/agents/issue-tracker.md` with the repo's **Product** coordinate. Without it, ask for `--product` rather than guessing.

Run from the **primary checkout**, not from inside a worktree. A worktree cannot remove itself, and `git branch -d` fails on a branch checked out elsewhere.

## Process

### 1. Survey (always, before touching anything)

Build the full picture first and print it as one table. This is the whole output of `--dry-run`, and the thing the user reads before confirming.

```bash
git worktree list --porcelain
git worktree prune --dry-run   # what git already considers gone
```

For each worktree **other than the primary**, collect:

| Field | How |
| --- | --- |
| Path, branch | `git worktree list --porcelain` |
| Dirty? | `git -C <path> status --porcelain` — **non-empty means real work**, see below |
| Unpushed? | `git -C <path> log --oneline @{u}.. 2>/dev/null` (no upstream ⇒ treat as unpushed) |
| Merged? | `gh pr list --head <branch> --state merged --json number,url` — falls back to `git branch --merged <base>` when the branch never had a PR |

> `git status --porcelain` **excludes gitignored files**, so `dist/`, `node_modules/`, and build output do not make a worktree dirty. What does show up is real: a modified tracked file, or an untracked source file. Treat any non-empty output as work that might not exist anywhere else.

### 2. Classify each worktree

Four buckets. Only the first two are acted on without asking.

- **Prunable** — the directory is already gone and git just holds a stale record. `git worktree prune`.
- **Landed and clean** — branch merged, `status --porcelain` empty, nothing unpushed. **Remove it.**
- **Landed but dirty, or has unpushed commits** — the branch merged, but there is state on disk that merging didn't capture. **Stop and ask, one worktree at a time**, showing the actual `git status` / unpushed log output. Removing this needs `--force`, and `--force` discards it permanently. Never batch this question — the answer is per-worktree.
- **Still active** — branch not merged (open PR, or no PR at all). **Leave it.** Report it so the user sees what is still in flight; do not offer to delete it.

### 3. Remove the landed worktrees

Per worktree, in this order:

```bash
git worktree remove <path>              # add --force ONLY with per-item confirmation from step 2
git branch -d <branch>                  # -d, never -D: it refuses if unmerged, which is the point
git push origin --delete <branch>       # only if the remote branch still exists
```

`git worktree remove` refuses when there are modified or untracked files, so it is a real second safety net even after step 2's check — if it errors, **do not reach for `--force` to make the error go away**. Go back and ask.

Then a final `git worktree prune` to clear anything left over.

### 4. Sweep the Tickets

Resolve the product (`--product`, else the **Product** line in `docs/agents/issue-tracker.md`), then:

```bash
exponential tickets list --product <product> --status QA --json
```

For each `QA` Ticket, decide from evidence:

- **No `prUrl`** → skip. Report as `no PR linked`. This usually means it was moved to `QA` by hand and nobody knows if it shipped.
- **`prUrl` set** → ask GitHub, don't infer:

  ```bash
  gh pr view <prUrl> --json state,mergedAt,url
  ```

  - `state: MERGED` → **promote.**
  - `state: OPEN` → skip, `still in review`.
  - `state: CLOSED` (not merged) → skip, `PR closed without merging` — flag this one loudly, it is usually abandoned work sitting in the wrong column.

Promote with:

```bash
exponential tickets update --id <cuid> --status DONE
```

One call per Ticket. If a call fails, record it and carry on — a single tracker error must not abandon the rest of the sweep.

> `DONE`, not `ARCHIVED`. `ARCHIVED` is the triage tracker's `wontfix`; using it here would misfile shipped work as abandoned.

### 5. Report

One summary, listing by outcome:

- Worktrees removed (with their branches), and branches deleted local/remote.
- Worktrees **left alone** and why — `dirty`, `unpushed`, `still in flight`. This half matters more than the removals; it is the list of things still needing attention.
- Tickets promoted `QA → DONE`, each with its PR link.
- Tickets **skipped** and why, grouped by reason.

If the sweep did nothing, say that plainly — "nothing to close" is a good outcome, not a failure to report around.

## Failure modes

- **Run from inside a worktree** — refuse with the primary checkout's path (`git worktree list` names it first). A worktree cannot remove itself.
- **`gh` not authenticated** — refuse the whole sweep. Without merge state every action would be a guess, and guessing is the one thing this skill exists to avoid.
- **Branch merged via squash** — `git branch --merged` will **not** list it, because a squash merge makes a new commit. This is why the PR lookup is primary and `--merged` only the fallback for branches that never had a PR. Do not "fix" a squash-merged branch's absence from `--merged` by relaxing to `git branch -D`.
- **`git push origin --delete` fails** — the remote branch was already deleted (common: `gh pr merge --delete-branch`). Not an error; note it and move on.
- **Ticket has a `prUrl` pointing at another repo** — `gh pr view <url>` handles full URLs across repos, so this works. If it 404s, skip and report rather than assuming.
- **No `docs/agents/issue-tracker.md`** — ask for `--product`. Don't scan the workspace's products hoping to match the repo name.

## What this skill does NOT do

- It does not merge anything. `/ship-this` and `/ship-ticket` merge; this runs after.
- It does not close Features, only Tickets. A Feature's status is a judgement about the outcome, not about whether a PR landed.
- It does not touch `IN_PROGRESS`, `BLOCKED`, or `BACKLOG` Tickets — only `QA`.
- It does not replace `/setup-merge-hook`. If you are sweeping the same repo repeatedly, run that instead and let the Action do this on every merge.
