---
"mattpocock-skills": minor
---

Add the **`close-shipped`** skill — a sweep over work that has already landed. It removes the git worktrees whose branches merged and promotes Exponential Tickets from `QA` to `DONE`, closing the gap `/ship-ticket` leaves behind.

The gap is real and specific. `/ship-ticket` ends with the Ticket in `QA` and a worktree on disk; `/setup-merge-hook` scaffolds a GitHub Action to finish the job, but only for repos where it's been wired, and never for the worktrees. Where it hasn't, `QA` becomes a graveyard and `git worktree list` grows past the work actually in flight.

**Every action is gated on evidence that the work merged**, which is the whole design. Merge state is read from `gh pr view`, not inferred from a branch looking stale or a Ticket looking done. A `QA` Ticket with no `prUrl` is skipped and reported; one whose PR is `OPEN` stays in `QA`; one whose PR was `CLOSED` without merging is flagged loudly, since that's usually abandoned work filed in the wrong column. `DONE`, never `ARCHIVED` — `ARCHIVED` is triage's `wontfix`, and using it here would misfile shipped work as abandoned.

Worktrees sort into four buckets, and only two are acted on unasked: **prunable** (git already lost the directory) and **landed and clean** get removed; **landed but dirty or with unpushed commits** stops and asks per worktree, showing the actual `git status` output, because `--force` discards that work permanently; **still active** is left alone. The report leads with what was *not* touched — that list is the one needing a human.

Two traps are called out in the skill because both silently corrupt a naive sweep. `git status --porcelain` excludes gitignored files, so `dist/` and `node_modules/` don't make a worktree dirty but a modified tracked file does. And `git branch --merged` does not list **squash-merged** branches — a squash creates a new commit — so a sweep built on `--merged` alone classifies most modern PRs as unmerged; the PR lookup is primary here and `--merged` only the fallback for branches that never had a PR.

User-invoked (`disable-model-invocation: true`), since removing worktrees and rewriting tracker state shouldn't happen unprompted. Routed in `ask-matt` under Codebase health, listed in the top-level and Engineering READMEs, added to `.claude-plugin/plugin.json`, and wired into `EXPONENTIAL-TEAM.md` at the two places that previously said tickets stay in `QA` and you flip them by hand.
