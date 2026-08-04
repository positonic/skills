# Skills For The Exponential Team

**This is the canonical doc for how we work with agent skills.** Read it end-to-end once; afterwards it's a reference. If anything here disagrees with another doc (including the upstream `README.md` or the vendored `docs/` pages), this doc wins — fix the other one.

This is our fork of [mattpocock/skills](https://github.com/mattpocock/skills), rebuilt around [Exponential](https://www.exponential.im) as the tracker: two-zone PRDs, one-ticket-per-scope backlogs, and a git lifecycle that drives ticket status automatically.

## Why use this

Coding agents fail in predictable ways. They build the wrong thing, drown you in verbose code, ship subtly broken behaviour, and accelerate the codebase into a ball of mud. These skills are an opinionated answer to each of those failure modes:

- **Misalignment** → `/grill-with-docs` interviews you until you and the agent agree on what's being built
- **Verbosity** → grounding in a project-specific `CONTEXT.md` cuts both prose and code bloat
- **Broken code** → `/tdd`, `/implement`, and `/diagnosing-bugs` enforce real feedback loops
- **Architectural drift** → `/code-review` and `/improve-codebase-architecture` keep the design intentional

The skills are small, composable, and model-agnostic. They don't replace your judgement; they structure it.

## The workflow

### Step 0 — size the effort

Ask one question: **could I settle every open question about this in a single sitting?**

- **Yes → start at `/grill-with-docs`.** This is the default, ~90% of the time — a feature, a refactor, a change with a handful of open questions. Grill is a *conversation*.
- **No → start at `/wayfinder`.** The signal is **fog**: you can feel the shape of the effort but couldn't write the spec yet, because too many decisions depend on decisions you haven't made — greenfield products, huge multi-feature builds. Wayfinder is a *campaign*: it charts a shared map of decision tickets on Exponential (map = a Feature, children = tickets with native blocking) that you and teammates burn down across days. When the fog clears, it hands off to the normal flow below.

Both directions self-correct: `/wayfinder` stops early if its opening questions surface no fog ("this fits one session — skip the map"), and a grilling session that's drowning in multiplying questions is your cue to escalate to wayfinder.

### Steps 1–3 — plan (one unbroken session)

Keep these in **one session, without clearing context** — the tickets should inherit the thinking.

1. **`/grill-with-docs`** — the agent interviews you one question at a time, challenges your terms against `CONTEXT.md` and the ADRs, and updates them as decisions crystallise. It won't proceed until you confirm shared understanding.
2. **`/to-prd`** — turns the settled conversation into the **human PRD**: a Knowledge page linked to an Exponential Feature (checking the registry first so it extends rather than duplicates), with scopes and EARS requirements as native, checkable rows.
3. **`/to-robo-prd`** then **`/to-tickets`** — appends the **Agent PRD** (implementation decisions, testing decisions, scope map with tracer bullets, rejected alternatives) to the same page, then cuts the work into **few tickets** — default one per scope — with the vertical slices as **ordered actions** on each ticket. One ticket = one branch = one PR; one action = one commit. Branch names are pre-assigned, blocking edges wired, and it ends by printing a clean-context execution prompt.

*(A loose plan that doesn't belong to a registry feature? Use `/to-expo` instead of steps 2–3.)*

### Step 4 — execute (fresh session per ticket)

Work one ticket at a time, in dependency order, each in a **fresh session** (paste the execution prompt from `/to-tickets`):

1. **`/start-ticket EXPO-N`** — fetches the ticket, moves it to `IN_PROGRESS`, checks out its branch, writes the `.exponential/current-ticket` marker.
2. **Build the actions in numbered order, one commit per action.** Use **`/implement`** — it drives `/tdd` red-green at the seams agreed in the PRD, then closes out with `/code-review` before committing. After every action the branch must be demoable. Mark each action done: `exponential actions update --id <id> --status COMPLETED`.
3. **`/ship-ticket`** — runs your test/type/lint suite, commits leftovers with the right trailers, opens a PR against the base from your git-flow config, links `ticket.prUrl`, moves the ticket to `QA`.
4. **Merge the PR before starting any ticket that depends on it.** Independent tickets can run in parallel. On merge to the deploy trigger, the merge hook flips the ticket to `DONE` — you never touch its status by hand.

**Stacking** (exception, for tightly-coupled tickets that shouldn't be reviewed separately): stay on the branch, `/start-ticket` the next ticket, work it, `/ship-ticket` again — it appends to the same PR.

### Situational skills — reach for when needed

| Situation | Command |
|---|---|
| Something's broken, throwing, or slow | `/diagnosing-bugs` — reproduce → minimise → hypothesise → fix → regression-test |
| Review a branch, PR, or diff | `/code-review` — standards + spec fidelity + Fowler code smells, in parallel sub-agents |
| Need facts before deciding (docs, APIs, specs) | `/research` — background agent reads primary sources, leaves a cited markdown file; you keep working |
| Unsure whether a design/state model feels right | `/prototype` — throwaway code that answers the question |
| Raw reports piling up in the tracker | `/triage` — verifies claims and routes each to `READY_TO_PLAN` / `BLOCKED` / `NEEDS_REFINEMENT` / `ARCHIVED` |
| One-off change, no ticket ceremony | `/ship-this` — commit → PR → automated review + autofix loop → CI → squash-merge |
| Repo getting muddy | `/improve-codebase-architecture` — run weekly-ish |
| `QA` filling up, or stale worktrees piling on disk | `/close-shipped` — removes merged worktrees and promotes `QA` → `DONE`, gated on the PR actually having merged |
| Quick design stress-test, no repo/artifacts | `/grill-me` (see FAQ for how it differs from `/grill-with-docs`) |
| Lost? | `/ask-matt` — describe your situation; it names the skill |

### If you know upstream's flow

Matt's canonical chain is `grill-with-docs → to-spec → to-tickets → implement → code-review`. Ours is the same spine with three deliberate differences — the decoder ring for his videos and docs:

| Matt says | We do | Difference |
|---|---|---|
| `grill-with-docs` | `/grill-with-docs` | Identical. |
| `to-spec` | `/to-prd` + `/to-robo-prd` | Split into a human zone and an agent zone of one Exponential PRD page. |
| `to-tickets` | `/to-tickets` (ours) | He cuts many thin tickets; we cut **one ticket per scope** with the slices as ordered actions — fewer PRs, a backlog humans can read. |
| `implement` | `/start-ticket` → `/implement` → `/ship-ticket` | Same build skill, bracketed by the Exponential ticket lifecycle. His flow ends at commit; ours continues to `QA` → merge → auto-`DONE`. |
| `code-review` | `/code-review` | Identical (it also runs inside `/implement` before each commit). |
| `setup-matt-pocock-skills` | `/setup-syntro-skills` | Renamed; same job, Exponential-aware. |

## One-time setup

### 1. Authenticate the Exponential CLI

```bash
npm install -g exponential-cli@latest   # the PRD/ticket skills need >= 1.7.0
exponential auth status                 # already authed? you're good
exponential auth login                  # otherwise
exponential workspaces set-default <workspace-slug>
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

It probes for the Exponential CLI and proposes Exponential as the tracker, asks which workspace + product this repo maps to, and writes:

- `docs/agents/issue-tracker.md` — the CLI commands, triage status mapping, and **Wayfinding operations** (how `/wayfinder` expresses its map on Exponential), with your workspace/product baked in
- `docs/agents/triage-labels.md` — the canonical triage role vocabulary
- `docs/agents/domain.md` — where `CONTEXT.md` and ADRs live
- An `## Agent skills` block in `CLAUDE.md` / `AGENTS.md` pointing at the above

It also invokes `/setup-git-flow` as a sub-step: detects your repo's branching model (trunk-based, `develop → main`, or full `develop → staging → main`) from the remote branches, confirms with you, and writes `docs/agents/git-flow.md`. `/start-ticket` and `/ship-ticket` read it to pick the right base branch; `/setup-merge-hook` reads it to know which merge triggers `DONE`.

After this, every other skill "just works" against our Exponential product.

### 4. (Optional but recommended) Wire auto-promotion to `DONE` on merge

```
/setup-merge-hook
```

It sets an `EXPONENTIAL_TOKEN` repo secret and scaffolds `.github/workflows/exponential-promote.yml` (review, commit, push to activate). The Action handles direct PRs and rollup PRs transparently. Without it, tickets stay in `QA` after `/ship-ticket` — run `/close-shipped` to sweep them (it checks each ticket's PR actually merged before promoting), or flip them by hand.

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
| PR merges to your deploy trigger | `DONE` (auto, via GitHub Action) |

Where the Action isn't wired, `/close-shipped` does that last row on demand — a sweep over `QA` that promotes only the tickets whose PR GitHub confirms as merged, and clears out the worktrees those branches left behind.

The commit, the PR, and the ticket are linked three ways: `ticket.branchName` ↔ git branch, `ticket.prUrl` ↔ GitHub PR, and an `Exponential-Ticket: <cuid>` trailer on the commit `/ship-ticket` creates. The GitHub Action uses `ticket.prUrl` as the source of truth when promoting to `DONE`; the commit trailer is decoration for human `git log` readers.

## When you install these into a product repo

Agent skills are **personal developer tooling** — different team members use different agents and have different workflow preferences, so we keep them out of shared product repos. Treat them like your editor config: yours to tune, not ours to standardise.

If you install agent skills (Claude Code, Aider, Augment, etc.) into one of our product repos, make sure the following are in your **local** `.gitignore` and never committed:

- `.agents/`
- `.claude/`
- `skills-lock.json`
- Any other agent-specific config directories (`.aider*`, etc.)

If you discover one of these has been accidentally committed historically, raise it — we'll remove it.

## FAQ

### When `/grill-with-docs` and when `/wayfinder`?

See [Step 0](#step-0--size-the-effort). Short version: grill is a conversation (one session settles everything); wayfinder is a campaign (a persistent map of decision tickets for efforts too foggy to spec in one sitting). Wrong guesses self-correct — wayfinder exits early when there's no fog, and a drowning grill session is your cue to escalate.

### What's the difference between `/grill-me` and `/grill-with-docs`?

Both run a one-question-at-a-time interview to stress-test a plan. The difference is what they check it against.

**`/grill-me`** — Plain grilling. Walks the decision tree, asks one question at a time, recommends an answer, explores the codebase for *facts* (decisions always come to you). Generic, lightweight, no artifacts produced.

**`/grill-with-docs`** — Same grilling loop, but anchored to the repo's domain model. It additionally:

- Reads `CONTEXT.md` / `CONTEXT-MAP.md` and the ADRs first, then challenges your terms against the existing glossary ("you said 'account' — do you mean Customer or User?")
- Cross-references claims with the actual code and surfaces contradictions
- Writes documentation inline as decisions crystallise — updates `CONTEXT.md` when a term is resolved, offers ADRs sparingly (only when the decision is hard to reverse, surprising, and a real trade-off)

**Rule of thumb**: use `/grill-me` for a quick design stress-test on something throwaway or pre-repo; use `/grill-with-docs` when the plan touches a real codebase with a domain language you want to keep coherent and documented.

### How do I add, edit, or improve a skill?

You need a Mode A install (clone + symlinks) — your edits take effect in the next session, no reinstall. The flow:

1. **Edit an existing skill** at `skills/<bucket>/<name>/SKILL.md`, or **create a new one** with the help of `/writing-great-skills` (the discipline for writing skills that steer well).

2. **Choose the right bucket** for new skills:
   - `skills/engineering/` — daily code work
   - `skills/productivity/` — daily non-code workflow tools
   - `skills/misc/` — kept around but rarely used (not shipped in the plugin)
   - `skills/in-progress/` — drafts not ready for the team yet

3. **Test live** by running the skill in any repo — `link-skills.sh` symlinks from your working tree, so edits apply on the next session.

4. **If you're promoting a skill** to `engineering/` or `productivity/`, the repo's `CLAUDE.md` requires updating: the top-level `README.md`, the bucket's `README.md`, and `.claude-plugin/plugin.json`. Drafts in `in-progress/` must **not** appear in any of those. Run `claude plugin validate . --strict` after touching the manifests.

5. **Open a PR** against `main` on `positonic/skills`. Don't push directly to `main` — others install from it. If your PR adds/renames a skill, bump the plugin version (`plugin.json` + `package.json`, kept in sync) so plugin-mode users get the update.

6. **After merge**, announce it; teammates upgrade with `scripts/upgrade.sh`.

### How do we sync with upstream (mattpocock/skills)?

`git fetch upstream && git merge upstream/main` on a branch, then resolve by the policy in `CLAUDE.md` ("Fork conventions"): our planning-suite names win on collisions (`to-prd`, `to-robo-prd`, `to-tickets`, `setup-syntro-skills`); upstream's craft content is adopted and adapted. Port improvements into our versions rather than taking upstream's files.

## Tips and gotchas

- **Upgrading is always** `~/code/skills/scripts/upgrade.sh` (Mode A). It pulls, re-links, and prunes stale symlinks from renames.
- **New skills appear in your *next* session** — the slash-command list is loaded at session start.
- **`/setup-syntro-skills` is per-repo.** Run it once per repo. Re-run if you switch trackers or want to start clean.
- **You can hand-edit `docs/agents/*.md` after setup.** The other skills read these files; edits stick.
- **Triage roles use Exponential ticket statuses directly** — no labels, no body markers. Each role maps to a unique `ticket.status` so `/triage` can route on a single `--status` filter.
- **The `exponential` CLI must be on `$PATH` and authed** for any of the publish/read skills to work. If they fail with auth errors, run `exponential auth login` again.
- **Context hygiene**: plan (grill → PRD → tickets) in one unbroken session; execute each ticket in a fresh one. If a planning session approaches the smart zone (~120k tokens), `/handoff` and continue fresh rather than pushing on degraded.

## Credits & upstream

Forked from [mattpocock/skills](https://github.com/mattpocock/skills) — the upstream `README.md` in this repo has Matt's longer essay on *why* these skills exist (the four failure modes, the Pragmatic Programmer / DDD framings). Worth reading for the deeper rationale; not required to use the tools day-to-day. The vendored `docs/engineering/` and `docs/productivity/` pages are upstream's human docs — useful reference, but where they name `to-spec` or upstream's ticket model, translate via the table above; this doc is our canon.
