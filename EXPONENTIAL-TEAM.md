# Skills For The Exponential Team

The single onboarding doc for engineers on the Exponential team. Read this end-to-end once; you shouldn't need to read the upstream `README.md` to get going.

This is our fork of [mattpocock/skills](https://github.com/mattpocock/skills) with one substantive addition: an Exponential issue-tracker preset and a published `/to-expo` skill, so the whole workflow is plumbed end-to-end into our tracker without manual config.

## Why use this

Coding agents fail in predictable ways. They build the wrong thing, drown you in verbose code, ship subtly broken behaviour, and accelerate the codebase into a ball of mud. These skills are an opinionated answer to each of those failure modes:

- **Misalignment** → `/grill-with-docs` interviews you until you and the agent agree on what's being built
- **Verbosity** → grounding in a project-specific `CONTEXT.md` cuts both prose and code bloat
- **Broken code** → `/tdd` and `/diagnosing-bugs` enforce real feedback loops
- **Architectural drift** → `/improve-codebase-architecture` keeps the design intentional

The skills are small, composable, and model-agnostic. They don't replace your judgement; they structure it.

## The skills you'll use most

| Skill | When to reach for it |
|---|---|
| `/grill-with-docs` | Anytime you're starting a non-trivial change. The agent grills you, updates `CONTEXT.md` and ADRs as decisions crystallise. |
| `/to-prd` | Turn a settled conversation into the human PRD: a Knowledge page linked to a Feature, with EARS requirements as native rows. |
| `/to-robo-prd` | Append the Agent PRD (implementation detail, scope map, tracer bullets) to the bottom of the feature's PRD page. |
| `/to-tickets` | Turn the Agent PRD into few tickets (default one per scope) with the vertical-slice steps as ordered actions. Each ticket gets an auto-assigned `branchName`. |
| `/to-expo` | Break a loose plan (no registry feature) into independently-grabbable tickets using vertical slices. For feature work, prefer `/to-tickets`. |
| `/triage` | Sort the incoming ticket backlog by routing each one to the right state (ready-for-agent, ready-for-human, needs-info, etc). |
| `/start-ticket` | Pick up a `READY_TO_PLAN` ticket: checks out its branch, moves it to `IN_PROGRESS`, drops a `.exponential/current-ticket` marker so `/ship-ticket` knows which ticket you're on. |
| `/tdd` | Build a feature with a red-green-refactor loop. Default mode for new functionality. |
| `/diagnosing-bugs` | Stuck on a bug or perf regression. Reproduce → minimise → hypothesise → fix → regression-test. |
| `/ship-ticket` | Done building: runs your test/type/lint suite, makes an atomic commit, opens a PR linked to the ticket, moves the ticket to `QA`. Run again on the same branch to **stack** another ticket onto the open PR. |
| `/improve-codebase-architecture` | Run weekly-ish on a repo that's getting messy — finds deepening opportunities grounded in the domain. |

Run any skill by typing `/<name>` in a Claude Code session.

## One-time setup

### 1. Authenticate the Exponential CLI

```bash
exponential auth status        # already authed? you're good
exponential auth login         # otherwise
exponential workspaces set-default <workspace-slug>   # so future commands don't need --workspace
```

### 2. Install the skills

Three install modes — pick one. The difference matters; see the comparison table below.

**Mode A — the team standard (clone + symlink, user-global):**

```bash
git clone git@github.com:positonic/skills.git ~/code/skills
~/code/skills/scripts/link-skills.sh
```

To upgrade later — one command, handles renamed/deleted skills too:

```bash
~/code/skills/scripts/upgrade.sh
```

Because the links point at your working tree, this is also the contributor mode: edits to the repo take effect in your next session.

**Mode B — managed plugin (auto-updating, curated set):**

In a terminal:

```bash
claude plugin marketplace add positonic/skills
claude plugin install syntro-skills@syntrofi
```

(Or the `/plugin` slash commands in a `claude` CLI session, or the **Manage Plugins** UI in the VSCode extension.) One-time; when we bump the plugin version on `main`, your install updates itself. Ships only the promoted skill set — no in-progress drafts. Don't combine with Mode A — you'd get every skill twice.

**Mode C — per-project copies (cherry-picking a subset):**

```bash
cd <your-repo>
npx skills@latest add positonic/skills
```

A picker appears. Always include `setup-syntro-skills`; include the rest based on taste. Note: re-run after each release, and delete stale copies yourself when skills are renamed.

### 3. Run setup in each repo

In a fresh Claude Code session opened in the target repo:

```
/setup-syntro-skills
```

The skill detects that Exponential is your tracker (if you're using Exponential for tracking and have it written as such in your AGENTS files..), asks which workspace + product this repo maps to, and writes:

- `docs/agents/issue-tracker.md` — the CLI commands and triage status mapping, with your workspace/product baked in
- `docs/agents/triage-labels.md` — the canonical triage role vocabulary
- `docs/agents/domain.md` — where `CONTEXT.md` and ADRs live
- An `## Agent skills` block in `CLAUDE.md` / `AGENTS.md` pointing at the above

After this, every other skill in the set "just works" against our Exponential product.

`/setup-syntro-skills` also invokes `/setup-git-flow` as a sub-step. That one detects your repo's branching model (trunk-based, `develop → main`, or full `develop → staging → main`) by inspecting remote branches via `gh`, confirms with you, and writes `docs/agents/git-flow.md`. `/ship-ticket` reads it to pick the right base branch for new PRs; `/setup-merge-hook` (below) reads it to know which merge triggers `DONE`.

### 4. (Optional but recommended) Wire the merge hook

Run:

```
/setup-merge-hook
```

It asks which of two things should happen when a PR merges to your trunk. They're independent — pick either, or both:

- **promote** — tickets move `QA` → `DONE` automatically, no manual status updates after `/ship-ticket`. Scaffolds `.github/workflows/exponential-promote.yml`.
- **requirements** — the merged ticket's scope has its feature requirements ticked **met**, and ticket status is left alone. Scaffolds `.github/workflows/exponential-requirements.yml`. Pick this (and not promote) if your repo keeps a human QA gate: you still get requirement coverage that tracks what actually shipped, without losing the gate.

Either way the skill sets your Exponential JWT as a repo secret called `EXPONENTIAL_TOKEN` via `gh secret set`, and captures the API URL plus your product/workspace into the workflow. It does **not** commit — review the workflow file, then commit and push to activate. The Action handles direct PRs (feature → trunk) and rollup PRs (e.g. `develop → main`) transparently.

Requirement ticking means "this shipped to trunk green", not "someone wrote it down". It assumes **one ticket = one scope = one PR**; if a scope ever spans several PRs, the first merge ticks the whole scope and over-claims. The generated workflow says so in its own comments.

Without any of this, tickets stay in `QA` after `/ship-ticket` and you flip them to `DONE` by hand.

## Install modes: which to pick

|   | Mode A: clone + `link-skills.sh` | Mode B: plugin | Mode C: `npx skills add` |
|---|---|---|---|
| Source | Your local working tree | Published plugin version | Pushed GitHub repo |
| Upgrades | `scripts/upgrade.sh` (one command) | **Automatic** on version bump | Manual re-run per release |
| Handles renames/deletions? | Yes — `upgrade.sh` prunes | Yes | No — stale copies linger |
| Sees uncommitted changes? | Yes (immediate) | No | No |
| Respects `plugin.json` filter? | No — links **everything**, including in-progress drafts | Yes — exactly the promoted set | Yes — curated, with a picker |
| Install scope | User-global (`~/.claude/skills/`, everywhere) | User-global (managed by Claude Code) | Project-scoped (`.claude/` in the current repo) |
| Right for | The team default: day-to-day use *and* editing skills without reinstall round-trips. | Set-and-forget: same curated set, zero maintenance, no clone needed. | Cherry-picking a subset, or hacking copies in one repo. |

**Rule of thumb**: everyone starts on Mode A (it's what the team runs). Pick Mode B if you don't want a clone on your machine.

## The Ticket lifecycle, at a glance

Once `/setup-syntro-skills` and `/setup-merge-hook` are wired, every state transition is driven by a skill or the merge event — no manual status updates needed.

| Action | Ticket status |
|---|---|
| `/to-tickets` / `/to-expo` files the ticket | `READY_TO_PLAN` |
| `/start-ticket EXPO-N` | `IN_PROGRESS` |
| `/ship-ticket` opens the PR | `QA` |
| PR merges to your trunk | `DONE` (auto, via GitHub Action) |

The commit, the PR, and the ticket are linked three ways: `ticket.branchName` ↔ git branch, `ticket.prUrl` ↔ GitHub PR, and an `Exponential-Ticket: <cuid>` trailer on the commit `/ship-ticket` creates. The GitHub Action uses `ticket.prUrl` as the source of truth when promoting to `DONE`; the commit trailer is decoration for human `git log` readers.

## A suggested daily workflow

A loop that uses the skills the way they were designed to compose. Adapt it.

1. **Idea → aligned spec.** Don't start coding. Open a Claude session and run `/grill-with-docs`. It interviews you about the change and updates `CONTEXT.md` / ADRs inline. You leave with a sharper definition than you started with.

2. **Spec → PRD in Exponential.** Run `/to-prd`. It checks whether the feature already exists in the registry (adding to it if so), then writes the human PRD as a Knowledge page linked to the feature, creates its scopes, and files the EARS requirements as native, checkable rows.

3. **PRD → Agent PRD.** When agents will build it, run `/to-robo-prd`. It appends an `## Agent PRD` section to the bottom of the same page: implementation decisions, testing decisions, a scope map with tracer bullets, rejected alternatives.

4. **Agent PRD → tickets.** Run `/to-tickets`. It cuts the work into FEW tickets - default one per scope - with the vertical-slice steps as ordered actions on each ticket (one branch, one PR, commit per action). The backlog stays readable; agents keep their detail. (`/to-expo` remains for plans that don't belong to a registry feature.)

5. **Backlog → routed work.** Whenever new tickets land in `BACKLOG`, run `/triage`. It moves each to:
   - `READY_TO_PLAN` if fully specified for an agent
   - `BLOCKED` if it needs a human's judgement
   - `NEEDS_REFINEMENT` (with a comment carrying the question) if more info is needed
   - `ARCHIVED` if it won't be actioned

6. **Start a ticket.** Pick one from the `READY_TO_PLAN` queue and run `/start-ticket EXPO-N`. It checks out the ticket's branch (creating if needed), moves the ticket to `IN_PROGRESS`, and drops `.exponential/current-ticket` so the next skill knows which ticket you're on.

7. **Build.** `/tdd` for new functionality, `/diagnosing-bugs` for bugs.

8. **Ship.** When the work is done, run `/ship-ticket` — no arguments needed. It auto-detects the ticket from the marker, runs your discovered test/type/lint commands (use `--skip-checks` for a draft PR if work is unfinished), creates an atomic commit with the right trailer, opens a PR against the base branch from your git-flow config, links `ticket.prUrl`, and moves the ticket to `QA`.

   **Stacking**: if you want to bundle a tightly-coupled second ticket into the same PR, stay on the branch, run `/start-ticket EXPO-M`, do the work, then `/ship-ticket` again. The skill detects the open PR and appends to it; both tickets end up linked to the same PR URL.

9. **Merge.** When the PR merges to your trunk, the GitHub Action scaffolded by `/setup-merge-hook` finds the linked ticket(s) — directly or by walking rollup-PR commit messages for child PR refs — and, depending on the mode you chose, moves them to `DONE` and/or ticks their scope's feature requirements as met. You don't touch the ticket again.

10. **Maintain the design.** Once a week-ish, run `/improve-codebase-architecture` on the repo. It surfaces refactors grounded in our domain language.

The skills are designed to be invoked at the moment you'd already pause to think. They don't replace the pause — they structure it.

## When you install these into a product repo

Agent skills are **personal developer tooling** — different team members use different agents and have different workflow preferences, so we keep them out of shared product repos. Treat them like your editor config: yours to tune, not ours to standardise.

If you install agent skills (Claude Code, Aider, Augment, etc.) into one of our product repos, make sure the following are in your **local** `.gitignore` and never committed:

- `.agents/`
- `.claude/`
- `skills-lock.json`
- Any other agent-specific config directories (`.aider*`, etc.)

If you discover one of these has been accidentally committed historically, raise it — we'll remove it.

## FAQ

### What's the difference between `/grill-me` and `/grill-with-docs`?

Both run a one-question-at-a-time interview to stress-test a plan. The difference is what they check it against.

**`/grill-me`** — Plain grilling. Walks the decision tree, asks one question at a time, recommends an answer, explores the codebase when it can answer the question itself. Generic, lightweight, no artifacts produced.

**`/grill-with-docs`** — Same grilling loop, but anchored to the repo's domain model. It additionally:

- Reads `CONTEXT.md` / `CONTEXT-MAP.md` and `docs/adr/` first, then challenges your terms against the existing glossary ("you said 'account' — do you mean Customer or User?")
- Cross-references claims with the actual code and surfaces contradictions
- Writes documentation inline as decisions crystallise — updates `CONTEXT.md` when a term is resolved, offers ADRs sparingly (only when the decision is hard to reverse, surprising, and a real trade-off)

**Rule of thumb**: use `/grill-me` for a quick design stress-test on something throwaway or pre-repo; use `/grill-with-docs` when the plan touches a real codebase with a domain language you want to keep coherent and documented.

### How do I add, edit, or improve a skill?

The flow:

1. **Switch to Mode B locally**, so your edits are picked up live without a commit-push round-trip:
   ```bash
   git clone git@github.com:positonic/skills.git ~/code/skills
   ~/code/skills/scripts/link-skills.sh
   ```

2. **Edit an existing skill** at `skills/<bucket>/<name>/SKILL.md`, or **create a new one** with the help of `/write-a-skill` (it scaffolds the folder, frontmatter, and structure correctly).

3. **Choose the right bucket** for new skills:
   - `skills/engineering/` — daily code work
   - `skills/productivity/` — daily non-code workflow tools
   - `skills/misc/` — kept around but rarely used
   - `skills/in-progress/` — drafts not ready for the team yet

4. **Test live** by running the skill in any repo. Because `link-skills.sh` symlinks from your working tree, edits take effect on the next session — no reinstall.

5. **If you're promoting a skill to a public bucket** (`engineering`, `productivity`, or `misc`), the repo's `CLAUDE.md` requires you to update three places so teammates get it:
   - Top-level `README.md` — add an entry in the right section
   - The bucket's `README.md` — add a one-line entry
   - `.claude-plugin/plugin.json` — add the path to the `skills` array

   Drafts in `skills/in-progress/` must **not** appear in any of those three files.

6. **Open a PR** against `main` on `positonic/skills`. Don't push directly to `main` — others install from it.

7. **After merge**, teammates pick up the change by re-running `npx skills@latest add positonic/skills` in their projects.

Fixes follow the same flow minus the bucket-choice step. Small fix? Edit, test, PR. Bigger redesign? Draft it under `skills/in-progress/` first, then graduate it once it's settled.

## Tips and gotchas

- **Re-run `npx skills@latest add positonic/skills` periodically** in each project to pull updates. It's idempotent.
- **`/setup-syntro-skills` is per-repo.** Run it once per repo. Re-run if you switch trackers or want to start clean.
- **You can hand-edit `docs/agents/*.md` after setup.** The other skills read these files; edits stick.
- **Triage roles use Exponential ticket statuses directly** — no labels, no body markers. Each role maps to a unique `ticket.status` so `/triage` can route on a single `--status` filter.
- **The `exponential` CLI must be on `$PATH` and authed** for any of the publish/read skills to work. If they fail with auth errors, run `exponential auth login` again.

## Credits & upstream

Forked from [mattpocock/skills](https://github.com/mattpocock/skills) — the upstream `README.md` in this repo has Matt's longer essay on *why* these skills exist (the four failure modes, the Pragmatic Programmer / DDD framings). Worth reading if you want the deeper rationale; not required to use the tools day-to-day.
