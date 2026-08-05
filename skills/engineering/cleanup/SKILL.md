---
name: cleanup
description: Tear down after work that has landed — remove the git worktree, delete its branch, promote its Exponential Tickets from `QA` to `DONE`, and give a straight answer on whether anything is still in flight. Defaults to the worktree you're standing in; `--all` sweeps the whole repo. Use when the user says "clean up" / "/cleanup", when a session's work has merged and the worktree or Ticket is still hanging around, or when `/ship-this` or `/ship-ticket` reaches its hand-off step after a real merge.
---

# Cleanup

The last step of a session. `/ship-this` and `/ship-ticket` end with a PR merged — and a worktree still on disk, a branch still local, and a Ticket still sitting in `QA`. Nothing clears those unless `/setup-merge-hook` is wired, and even then never the worktree. This is the teardown.

It ends with an **all-clear**: an explicit statement of whether anything about this work is still in flight, so you know whether you can close the tab or whether something still wants you. That verdict is as much the point of the skill as the deleting is.

Everything it does is gated on **evidence that the work actually merged** — a `MERGED` PR, or a branch reachable from the base. It never flips a Ticket because it looks done, never removes a worktree because it looks stale, and never gives the all-clear because nothing errored. A `QA` Ticket with no merged PR stays in `QA`; that's the signal that something still needs a human.

## Usage

```
/cleanup [--all] [--dry-run] [--product <slug>] [--worktrees-only | --tickets-only]
```

- **No flags** — **here mode**: tear down *this* worktree and the Tickets belonging to its branch.
- `--all` — **sweep mode**: every worktree in the repo and every `QA` Ticket in the product. Must be run from the primary checkout.
- `--dry-run`: survey and print the plan, change nothing. Do this first on a repo you haven't swept before.
- `--product <slug>`: override the product from `docs/agents/issue-tracker.md`.
- `--worktrees-only` / `--tickets-only`: run just one half.

With no flag, pick the mode from where you are: inside a non-primary worktree → here mode; in the primary checkout → sweep mode. Say which mode you picked, and why, before doing anything.

## Prerequisites

- Inside a git repo (`git rev-parse --show-toplevel`).
- `gh` authenticated (`gh auth status`) — merge state is read from GitHub, not guessed.
- For the Ticket half: `exponential auth status` ok, and `docs/agents/issue-tracker.md` with the repo's **Product** coordinate. Without it, ask for `--product` rather than guessing.

## Here mode

The common case: you just shipped, you're inside the worktree that did the work, and you want the desk cleared.

### 1. Locate yourself

```bash
git rev-parse --show-toplevel        # this worktree
git rev-parse --git-common-dir       # <primary>/.git ⇒ the primary checkout is its parent
git worktree list --porcelain        # the primary is listed first
git branch --show-current
```

If the toplevel *is* the primary checkout, there is no worktree to remove. Say so, run the Ticket half only, and offer `--all`.

### 2. Establish that the work landed

Three checks, all against evidence:

```bash
git status --porcelain                                  # empty = clean
git rev-parse --abbrev-ref --symbolic-full-name @{u}    # non-zero exit = NO upstream
git log --oneline @{u}..                                # only meaningful once the above succeeded
gh pr list --head <branch> --state merged --json number,url,mergedAt
```

> Check for the upstream **first, as its own command**, and never silence it with `2>/dev/null`. A branch with no upstream makes `git log @{u}..` print nothing and exit 0 once its error is swallowed — identical to a fully-pushed branch. Read that way, a branch whose commits exist nowhere but this disk classifies as clean and gets its worktree removed. **No upstream is the strongest possible "unpushed" signal, not the absence of one.**

> `git status --porcelain` **excludes gitignored files**, so `dist/`, `node_modules/`, and build output do not make a worktree dirty. What does show up is real: a modified tracked file, or an untracked source file. Treat any non-empty output as work that might not exist anywhere else.

If the PR isn't merged, or the tree is dirty, or there are unpushed commits — **stop the worktree half**. Don't delete, don't force. Carry the reason into the all-clear as an outstanding item, and still run the Ticket half; it reaches the same conclusion from the same evidence.

### 3. Sweep this branch's Tickets

Resolve the Tickets belonging to this work from all three sources, and union the results:

1. `.exponential/current-ticket` — the marker `/start-ticket` wrote (one CUID).
2. `exponential tickets list --branch <branch> --json`.
3. `exponential tickets list --pr <pr-url> --json` — catches stacked Tickets that share the PR but not the branch name.

Keep the ones in `QA`, then promote them exactly as [sweep mode's Ticket sweep](#4-sweep-the-tickets) does — same evidence gate, same `DONE`-not-`ARCHIVED` rule. A Ticket in any other status is left alone and reported.

### 4. Hand over the removal

**Never remove the worktree you are standing in.** Git refuses, and forcing it from a parent directory pulls the ground out from under the live session. Print the exact commands instead, as one copy-pasteable block:

```bash
cd <primary-checkout> && git worktree remove <this-worktree-path> && git branch -d <branch>
```

Add `git push origin --delete <branch>` only if the remote branch still exists — `gh pr merge --delete-branch` usually got there first.

This is the one step `/cleanup` hands back to you, and the all-clear says so explicitly rather than pretending the worktree is already gone.

## Sweep mode (`--all`)

Repo-wide. Run from the **primary checkout** — a worktree cannot remove itself, and `git branch -d` fails on a branch checked out elsewhere. If invoked with `--all` from inside a worktree, refuse and name the primary checkout's path.

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
| Dirty? | `git -C <path> status --porcelain` — **non-empty means real work**, see the note above |
| Unpushed? | `git -C <path> rev-parse --abbrev-ref --symbolic-full-name @{u}` first — non-zero exit means **no upstream**, which counts as unpushed. Only then `git -C <path> log --oneline @{u}..`. See the trap noted in here mode: swallowing the upstream error makes a never-pushed branch read as fully pushed |
| Merged? | `gh pr list --head <branch> --state merged --json number,url` — falls back to `git branch --merged <base>` when the branch never had a PR |

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

## The all-clear

Every run ends with one of two verdicts. Print it last, on its own, after the detail.

Give the **all-clear** only when every one of these holds, each from evidence already gathered:

- The PR for this work exists and GitHub reports it `MERGED` — in sweep mode, no worktree landed in the *still active* bucket.
- Working tree clean, nothing unpushed.
- Every Ticket found for this work is `DONE` — promoted this run, or already there.
- The worktree is removed, **or** (here mode) the removal command has been printed and is the only thing left.

Then say it plainly:

> ✅ **All clear.** Nothing left in flight for this work — you can close this tab.
> One command left: `cd <primary> && git worktree remove <path> && git branch -d <branch>`

If **any** item fails, do not print the all-clear. Print what's outstanding instead, each with the thing that would clear it:

> ⏳ **Not done yet.** Still in flight:
> - PR #42 is still `OPEN` — its Ticket stays in `QA` until it merges.
> - `<worktree>` has 3 modified files — commit or discard them, then re-run `/cleanup`.

The all-clear is a claim about the evidence, not about the run finishing without errors. A `--dry-run` never gives it. Neither does a run that skipped half the work via `--tickets-only` / `--worktrees-only` — say which half went unchecked.

## Report

Before the verdict, one summary listing by outcome:

- Worktrees removed (with their branches), and branches deleted local/remote — or, in here mode, the removal command handed back.
- Worktrees **left alone** and why — `dirty`, `unpushed`, `still in flight`. This half matters more than the removals; it is the list of things still needing attention.
- Tickets promoted `QA → DONE`, each with its PR link.
- Tickets **skipped** and why, grouped by reason.

If the sweep did nothing, say that plainly — "nothing to close" is a good outcome, not a failure to report around.

## Failure modes

- **`--all` from inside a worktree** — refuse with the primary checkout's path (`git worktree list` names it first). A worktree cannot remove itself.
- **Here mode, but the current branch has no merged PR** — the work hasn't landed. Change nothing, and say so; this is not the skill for abandoning work.
- **`gh` not authenticated** — refuse the whole sweep. Without merge state every action would be a guess, and guessing is the one thing this skill exists to avoid.
- **Branch merged via squash** — `git branch --merged` will **not** list it, because a squash merge makes a new commit. This is why the PR lookup is primary and `--merged` only the fallback for branches that never had a PR. Do not "fix" a squash-merged branch's absence from `--merged` by relaxing to `git branch -D`.
- **`git push origin --delete` fails** — the remote branch was already deleted (common: `gh pr merge --delete-branch`). Not an error; note it and move on.
- **Ticket has a `prUrl` pointing at another repo** — `gh pr view <url>` handles full URLs across repos, so this works. If it 404s, skip and report rather than assuming.
- **No `docs/agents/issue-tracker.md`** — ask for `--product`. Don't scan the workspace's products hoping to match the repo name.

## What this skill does NOT do

- It does not merge anything. `/ship-this` and `/ship-ticket` merge; this runs after.
- It does not remove the worktree it is running inside — it prints the command and says so in the all-clear.
- It does not close Features, only Tickets. A Feature's status is a judgement about the outcome, not about whether a PR landed.
- It does not touch `IN_PROGRESS`, `BLOCKED`, or `BACKLOG` Tickets — only `QA`.
- It does not replace `/setup-merge-hook`. If you sweep the same repo repeatedly, run that instead and let the Action do the Ticket half on every merge — you'll still want `/cleanup` for the worktrees and the all-clear.
