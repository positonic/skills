---
name: orchestrate-feature
description: Drive the main flow from a settled grill to open PRs — /to-prd, /to-robo-prd, /to-tickets, then one build agent per unblocked ticket (/start-ticket, /implement, /ship-ticket) — delegating each phase to a subagent on the right model.
argument-hint: "[feature cuid or name] [--from prd|robo-prd|tickets|build] [--merge]"
disable-model-invocation: true
---

# Orchestrate Feature

Run the main flow — `/to-prd` → `/to-robo-prd` → `/to-tickets` → per ticket, `/start-ticket` → `/implement` → `/ship-ticket` — without the human typing each step. You are the **conductor**: you hold the context, write the **brief** for each phase, pick its model, and relay its questions to the human. Subagents do the work.

Start after `/grill-with-docs` has reached shared understanding, or with `--from` at a later phase given a feature. Never run the grill: grilling is human-in-the-loop, and this skill is the away-from-keyboard half. A brief written from a half-grilled idea produces a confident, wrong PRD.

## How a phase runs

The chain's skills are user-invoked, so neither you nor a subagent can invoke them by name. You run them under the exception recorded in ADR 0005: resolve each by its **installed name** and have the subagent follow the file.

1. **Resolve the skill.** `~/.claude/skills/<name>/SKILL.md`, else `~/.agents/skills/<name>/SKILL.md`, else a `<name>/SKILL.md` anywhere under `~/.claude/plugins/` (a plugin install). None → stop and name the missing skill. Never fall back to a repo-relative path.
2. **Write the brief.** A handoff summary of the kind `/handoff` writes: everything the skill would otherwise "synthesize from the conversation" — the decisions made, the vocabulary settled, the rejected alternatives — plus every id the earlier phases produced (product, feature, page, scope, ticket CUIDs). Reference artifacts (the PRD page, ADRs, `CONTEXT.md`) by id or path rather than restating them. Redact secrets: the brief becomes a prompt.
3. **Spawn the subagent** on the phase's model (table below) with the brief, the skill path, and the **AFK rule**:
   > Read the skill file and run it exactly. Wherever the skill would ask the user something, stop and return the question with your recommended answer — never answer it yourself. Return the skill's own report-back, with every id you created.
4. **Relay.** Came back with questions → put them to the human, then **resume the same agent** with the answers; keep its context, don't respawn. Came back done → record the ids and start the next phase.

A phase is complete when the skill's report-back step has been returned with its ids and no question is left unanswered.

## The phases

| # | Phase | Skill | Input | Output | Model |
|---|---|---|---|---|---|
| 1 | PRD | `to-prd` | the grill, via the brief, plus the product | feature, page and scope CUIDs | opus |
| 2 | Agent PRD | `to-robo-prd` | feature CUID | page updated | strongest available, highest effort |
| 3 | Tickets | `to-tickets` | feature CUID | ticket table and execution prompt | opus |
| 4 | Build | `start-ticket`, `implement`, `ship-ticket` | one ticket | PR open, ticket in `QA` | opus, one agent per ticket |

Phase 2 gets the strongest model because every claim it writes is verified against the code and every ticket inherits its mistakes. Phases 1–3 are sequential — each reads the previous one's page in Exponential — so there is nothing to parallelise; the model choice per phase is the whole gain. The model names are Claude Code's; on another harness, map each to the equivalent tier. Where the harness lets you set reasoning effort per agent, follow the table; otherwise encode the thoroughness in the brief.

### The gate

`/to-tickets` ends by quizzing the human on the cut; relay that quiz like any other question. Once the tickets are published, present the **fan-out plan** — every ticket that is `READY_TO_PLAN`, AFK, and unblocked, with its branch and the worktree it will get — and wait for a yes. This is the one gate the skill adds itself: the build is the expensive half.

### The build, in waves

A **wave** is every ticket whose blockers are all merged. Merged is evidence, not inference: the blocker's ticket is `DONE`, or its linked PR reports `MERGED` from `gh pr view`. `QA` is not merged, and neither is a queued auto-merge. For each ticket in the wave, in parallel:

- Spawn an agent **in its own worktree**, fresh context, on the build model, off a clean featureBase (`docs/agents/git-flow.md`, default `main`).
- Its brief is the execution prompt `/to-tickets` emitted, narrowed to this one ticket: `start-ticket` first, then the actions in numbered order, each worked by the `implement` skill file (`/tdd` at the agreed seams, typecheck), one commit per action, each action marked `COMPLETED` as it lands, then `/code-review` once over the branch, then `ship-ticket` — with `--merge` only if the human passed `--merge` to you. Resolve the three skills by installed name as in step 1.
- The AFK rule applies. A `NEEDS_REFINEMENT` or HITL ticket, and any action that turns out wrong as written, comes back as a question — never a guess.

When the wave returns, report per ticket: PR URL, ticket status, and anything that bounced. Then:

- **With `--merge`**: `ship-ticket` asked for each PR to merge. Confirm each one is `MERGED` — branch protection can leave it queued — then compute the next wave and run it. Repeat until no ticket is left, or until a queued merge leaves the next wave empty, in which case stop and say what it is waiting on.
- **Without it**: the PRs are at ready for the human. Stop, and say exactly how to continue once they've merged: `/orchestrate-feature <feature> --from build`.

The build is complete when every ticket on the feature is in `QA` or `DONE`, or named in your report as blocked, HITL, or bounced. Nothing is silently skipped.

## Arguments

- **None**: start at phase 1 from the current conversation. The product comes from the conversation or the user; ask if neither names it.
- **`<feature>`**: CUID or name. Required with `--from`.
- **`--from prd|robo-prd|tickets|build`**: enter mid-chain. Before starting, verify the previous phase's output exists — a PRD page before `robo-prd`, an `## Agent PRD` section before `tickets`, tickets before `build` — and stop with the gap named if it doesn't.
- **`--merge`**: passed through to `/ship-ticket` so waves chain without a human merge.

## What this skill is not

It never restates the chain's steps; if a phase misbehaves, fix that phase's skill. And it never reaches a user-invoked skill any other way than the installed-name read above — the conditions in ADR 0005 are the whole licence.
