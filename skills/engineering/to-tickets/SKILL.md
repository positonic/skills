---
name: to-tickets
description: Turn a feature's Agent PRD into a small number of Exponential tickets - default one per scope - with the implementation steps as ordered actions on each ticket. The human-first successor to /to-expo for feature work.
disable-model-invocation: true
---

# To Tickets

Break a feature's planned work into **few tickets** with **ordered actions**. The backlog stays human-readable (one ticket per shippable increment), while agents keep their step-level detail (actions = the vertical slices `/to-expo` used to make into tickets).

The granularity rules, and where each piece of information lives:

| Level | Unit | Rule |
|---|---|---|
| Ticket | one branch, one PR, one QA entry | Default **one per scope**. Split only when a chunk is independently mergeable and worth its own PR (parallel work, early deploy, or an unreviewably large diff otherwise). |
| Action | one vertical slice, one commit | Ordered steps inside the ticket. Action 1 is the scope's **tracer bullet**; each further action is a vertical widening. |
| blocked-by | between tickets only | Order *within* a ticket is the action order; edges only where a real dependency crosses tickets. |

<vertical-slice-rules>
- Each action delivers a narrow but COMPLETE path through every layer it touches (schema, API, UI, tests) - after ANY action completes, the branch is in a demoable state.
- Action 1 is the tracer bullet: the thinnest end-to-end path proving the scope works.
- Each further action adds one complete behavior: an edge case handled end-to-end, another UI state, another input type.
- Horizontal, layer-bound actions (a migration, a mechanical refactor) are the exception, not the pattern.
</vertical-slice-rules>

## Prerequisites

`exponential auth status` must succeed. You need the target **feature** (CUID or name) - its Agent PRD is the input. If the feature has no `## Agent PRD` section on its PRD page, run `/to-robo-prd` first (or proceed from the human PRD alone only if the user says so).

## Process

### 0. Work in a fresh git worktree

Same as `/to-expo`: `git worktree add /tmp/<repo>-to-tickets HEAD`, work from inside it, offer to remove it at the end. Skip if not a git repo.

### 1. Gather the inputs

- `exponential features get <id> --json` - the feature, its scopes, its requirements.
- `exponential pages get <page-id> --json` for the linked PRD page - read both zones: the human PRD (goals, rollout) and the `## Agent PRD` (implementation decisions, scope map, tracer bullets).
- Explore the codebase where the Agent PRD's claims need verifying.

### 2. Draft the cut

For each scope (in rollout order), draft one ticket:

- **Title**: the scope's version + what it delivers ("V1: manual upload end-to-end").
- **Actions**: the ordered vertical slices from the scope map - tracer bullet first. Aim for 3-10 actions; if a scope wants more, that's a sign it should be two tickets (or two scopes - raise it).
- **Split** a scope into more than one ticket only for the reasons in the table above, and say why in the quiz.
- **Type**: `FEATURE` unless clearly `BUG`/`CHORE`/`IMPROVEMENT`/`SPIKE`/`RESEARCH`.
- **Status**: `READY_TO_PLAN` for AFK work; `NEEDS_REFINEMENT` where a human decision is still open (HITL).
- **Blocked-by**: only real cross-ticket dependencies ("V2 needs V1's schema merged").

### 3. Quiz the user

Present the cut as a numbered list. Per ticket: title, scope, HITL/AFK, blocked-by, and the action list. Ask:

- Is one-ticket-per-scope right here, or should any ticket be split (parallelism, early merge) or merged?
- Are the actions truly vertical (each one demoable), and is the tracer bullet first?
- Are the dependency edges real?

Iterate until approved.

### 4. Publish

In dependency order (blockers first):

```bash
exponential tickets create \
  --product <slug-or-cuid> \
  --feature <feature-cuid> \
  --scope <scope-cuid> \
  --type FEATURE --status READY_TO_PLAN \
  -t "<title>" -b "<body, per template below>" --json
```

Then per ticket:

- **Branch name** (so `/start-ticket`//`/ship-ticket` work): `exponential tickets update --id <cuid> --branch "<shortId-lowercased>-<slug(title)>"` (slug: lowercase, non-alphanumeric runs to `-`, trim, cap 50 chars).
- **Actions**, one per slice, numbered so the order is unambiguous:
  `exponential actions create -n "1) <tracer bullet>" -d "<what this slice delivers end-to-end + how to verify it>" --ticket <ticket-cuid> --json`
- **Dependencies**: `exponential tickets block <ticket-cuid> --by <blocker-cuid>` - cross-ticket only.
- **Decision comments** where the framing isn't obvious from the body (why a scope was split, why a status, rejected alternatives): `exponential tickets comment --id <cuid> -b "<1-3 sentences>"`.

Do NOT modify the feature, its scopes, or pre-existing tickets beyond this.

### 5. Report back

List each created ticket with CUID, shortId, scope, action count, and dependency edges.

### 6. Emit a clean-context execution prompt

End with a fenced code block containing a self-contained prompt for a fresh session. Include the feature CUID, the product slug, and the ticket table (CUID, shortId, title, scope, status, HITL/AFK, blocked-by). The working rules differ from /to-expo's - one PR per ticket, commit per action:

<execution-prompt-template>
````
You are picking up tickets for feature `<feature-cuid>` in Exponential. Work one ticket at a time, in dependency order.

**Product**: `<product-slug>` | **Feature**: `<feature-cuid>` - fetch with `exponential features get <cuid> --json`; read its linked PRD page (`exponential pages get <page-id> --json`), especially the `## Agent PRD` section.

**Tickets** (dependency order):

| # | CUID | shortId | Title | Scope | Status | HITL/AFK | Blocked by |
|---|------|---------|-------|-------|--------|----------|------------|
| 1 | <cuid> | <shortId> | <title> | V1 | READY_TO_PLAN | AFK | - |

**How to work a ticket** (one branch, one PR, commit per action):

0. Get on a clean base: `git checkout <featureBase>` (from `docs/agents/git-flow.md`; default `main`) `&& git pull`.
1. `/start-ticket <cuid>` - fetches the body, moves it to IN_PROGRESS, checks out its branch.
2. List its actions: they're included in `exponential tickets get <cuid> --json`. Work them **in numbered order**.
3. Per action: implement the whole vertical slice, verify it works, make ONE commit named after the action, then mark it done: `exponential actions update --id <action-id> --status COMPLETED`. After every action the branch must be demoable.
4. When all actions are done: `/ship-ticket` - one PR for the whole ticket; the ticket moves to QA.
5. Merge the PR before starting any ticket that depends on this one. Independent tickets may proceed in parallel off `main`.
6. On NEEDS_REFINEMENT / HITL tickets, stop and surface the open question - don't guess.
7. If an action turns out to be wrong or impossible as written, comment on the ticket (`exponential tickets comment --id <cuid> -b "..."`) and pause - don't silently re-plan.
````
</execution-prompt-template>

### 7. Offer to clean up the worktree

`git worktree remove /tmp/<repo>-to-tickets` - ask first.

## Ticket body template

<ticket-template>
## Parent

Feature `<feature-cuid>` / scope `<version>`. PRD: page `<page-cuid>` (read the `## Agent PRD` section).

## What to build

What this scope delivers, end-to-end, in a few sentences. The step detail lives in this ticket's actions - keep the body readable for a human scanning the board.

## Actions

1. <tracer bullet - thinnest end-to-end path>
2. <vertical widening>
3. ...

(Also created as native actions on this ticket - the checklist there is canonical; check actions off as commits land.)

## Acceptance criteria

- [ ] The scope's requirement rows on the feature are met (list the key ones)
- [ ] <anything not captured by a requirement row>

## Blocked by

- `<ticket-cuid-or-shortId>` - <why> (or "None - can start immediately")
</ticket-template>

## Relationship to /to-expo

`/to-expo` remains available for plans that don't live in the feature registry (loose specs, cross-product epics, standalone tickets). Use `/to-tickets` when the work belongs to a feature with a PRD - it produces the same machinery (branch names, dependencies, execution prompt) with a board humans can actually read.
