# Skills For The Exponential Team

The single onboarding doc for engineers on the Exponential team. Read this end-to-end once; you shouldn't need to read the upstream `README.md` to get going.

This is our fork of [mattpocock/skills](https://github.com/mattpocock/skills) with one substantive addition: an Exponential issue-tracker preset and a published `/to-expo` skill, so the whole workflow is plumbed end-to-end into our tracker without manual config.

## Why use this

Coding agents fail in predictable ways. They build the wrong thing, drown you in verbose code, ship subtly broken behaviour, and accelerate the codebase into a ball of mud. These skills are an opinionated answer to each of those failure modes:

- **Misalignment** → `/grill-with-docs` interviews you until you and the agent agree on what's being built
- **Verbosity** → grounding in a project-specific `CONTEXT.md` cuts both prose and code bloat
- **Broken code** → `/tdd` and `/diagnose` enforce real feedback loops
- **Architectural drift** → `/improve-codebase-architecture` and `/zoom-out` keep the design intentional

The skills are small, composable, and model-agnostic. They don't replace your judgement; they structure it.

## The skills you'll use most

| Skill | When to reach for it |
|---|---|
| `/grill-with-docs` | Anytime you're starting a non-trivial change. The agent grills you, updates `CONTEXT.md` and ADRs as decisions crystallise. |
| `/to-prd` | Turn a settled conversation into a PRD and file it in Exponential as a feature. |
| `/to-expo` | Break a PRD/plan into independently-grabbable Exponential tickets using vertical slices. |
| `/triage` | Sort the incoming ticket backlog by routing each one to the right state (ready-for-agent, ready-for-human, needs-info, etc). |
| `/tdd` | Build a feature with a red-green-refactor loop. Default mode for new functionality. |
| `/diagnose` | Stuck on a bug or perf regression. Reproduce → minimise → hypothesise → fix → regression-test. |
| `/improve-codebase-architecture` | Run weekly-ish on a repo that's getting messy — finds deepening opportunities grounded in the domain. |
| `/zoom-out` | Ask the agent to explain a piece of code in the context of the whole system before you touch it. |

Run any skill by typing `/<name>` in a Claude Code session.

## One-time setup

### 1. Authenticate the Exponential CLI

```bash
exponential auth status        # already authed? you're good
exponential auth login         # otherwise
exponential workspaces set-default <workspace-slug>   # so future commands don't need --workspace
```

### 2. Install the skills

Two install modes — pick one. The difference matters; see the comparison table below.

**Mode A — for most engineers (stable, per-project, curated set):**

```bash
cd <your-repo>
npx skills@latest add positonic/skills
```

A picker appears. Always include `setup-matt-pocock-skills` and `to-expo`; include the rest based on taste.

**Mode B — for skill contributors (live edits, user-global):**

```bash
git clone git@github.com:positonic/skills.git ~/code/skills
~/code/skills/scripts/link-skills.sh
```

### 3. Run setup in each repo

In a fresh Claude Code session opened in the target repo:

```
/setup-matt-pocock-skills
```

The skill detects that Exponential is your tracker, asks which workspace + product this repo maps to, and writes:

- `docs/agents/issue-tracker.md` — the CLI commands and triage status mapping, with your workspace/product baked in
- `docs/agents/triage-labels.md` — the canonical triage role vocabulary
- `docs/agents/domain.md` — where `CONTEXT.md` and ADRs live
- An `## Agent skills` block in `CLAUDE.md` / `AGENTS.md` pointing at the above

After this, every other skill in the set "just works" against our Exponential product.

## Install Mode A vs Mode B: which to pick

|   | Mode A: `npx skills add` | Mode B: `link-skills.sh` |
|---|---|---|
| Source | Pushed GitHub repo | Your local working tree |
| Sees uncommitted changes? | No | Yes (immediate) |
| Respects `plugin.json` filter? | Yes — only curated, published skills | No — links **everything**, including in-progress drafts |
| Install scope | Project-scoped (`.claude/` in the current repo) | User-global (`~/.claude/skills/`, available everywhere) |
| Picker UI? | Yes, you choose which skills to install | No, links everything |
| Right for | Day-to-day use. Same skill set as your teammates. | Editing the skills themselves and iterating without commit-push round-trips. |

**Rule of thumb**: if you're not editing the skills repo, you want Mode A. If you are, Mode B.

## A suggested daily workflow

A loop that uses the skills the way they were designed to compose. Adapt it.

1. **Idea → aligned spec.** Don't start coding. Open a Claude session and run `/grill-with-docs`. It will interview you about the change and update `CONTEXT.md` / ADRs inline. You leave with a sharper definition than you started with.

2. **Spec → PRD in Exponential.** Run `/to-prd`. It synthesises the conversation into a PRD and files it as a feature in Exponential (`status: DEFINED`).

3. **PRD → tickets.** Run `/to-expo`. It breaks the PRD into vertical-slice tickets with explicit dependencies, filed under the feature.

4. **Backlog → routed work.** Whenever new tickets land in `BACKLOG`, run `/triage`. It moves each to:
   - `READY_TO_PLAN` if fully specified for an agent
   - `BLOCKED` if it needs a human's judgement
   - `NEEDS_REFINEMENT` (with a comment carrying the question) if more info is needed
   - `ARCHIVED` if it won't be actioned

5. **Pick up a ticket and build.** Read the ticket, open a Claude session, and use `/tdd` for new functionality. For bugs, start with `/diagnose`. Use `/zoom-out` first if the code area is unfamiliar.

6. **Maintain the design.** Once a week-ish, run `/improve-codebase-architecture` on the repo. It surfaces refactors grounded in our domain language.

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
- **`/setup-matt-pocock-skills` is per-repo.** Run it once per repo. Re-run if you switch trackers or want to start clean.
- **You can hand-edit `docs/agents/*.md` after setup.** The other skills read these files; edits stick.
- **Triage roles use Exponential ticket statuses directly** — no labels, no body markers. Each role maps to a unique `ticket.status` so `/triage` can route on a single `--status` filter.
- **The `exponential` CLI must be on `$PATH` and authed** for any of the publish/read skills to work. If they fail with auth errors, run `exponential auth login` again.

## Credits & upstream

Forked from [mattpocock/skills](https://github.com/mattpocock/skills) — the upstream `README.md` in this repo has Matt's longer essay on *why* these skills exist (the four failure modes, the Pragmatic Programmer / DDD framings). Worth reading if you want the deeper rationale; not required to use the tools day-to-day.
