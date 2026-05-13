---
name: to-expo
description: Break a plan, spec, or PRD into independently-grabbable tickets in Exponential using tracer-bullet vertical slices. Use when user wants to convert a plan into Exponential tickets, push slices to Exponential, or break work down into tickets / features / epics in Exponential.
---

# To Expo

Break a plan into independently-grabbable **tickets** in Exponential using vertical slices (tracer bullets). Tickets are the unit of backlog work; they live under a **product** and can be grouped by a **feature** (product-scoped) or an **epic** (workspace-scoped, cross-product).

Hierarchy reminder: `workspace -> product -> feature -> ticket -> action`. Epics are a workspace-scoped cross-cut.

## Prerequisites

`exponential auth status` must succeed. If not, instruct the user to run `exponential auth login --token <jwt> --api-url <url>`.

You will need a target **product** (slug or CUID). If the user hasn't said which, ask — it's required to file tickets. Use `exponential products list --workspace <slug|id> --json` to enumerate options.

## Process

### 1. Gather context

Work from whatever is already in the conversation. If the user passes a ticket reference (CUID, shortId, or URL) as an argument, fetch it with `exponential tickets get <id> --json` and read its body, dependencies, and comments.

### 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code. Ticket titles and descriptions should use the project's domain glossary vocabulary, and respect ADRs in the area you're touching.

### 3. Decide on a grouping

Ask the user (or infer):

- **Existing feature?** If yes, capture its CUID — every ticket will get `--feature <id>`.
- **Existing epic?** If yes, capture its CUID — every ticket will get `--epic <id>`.
- **New feature?** Create one with `exponential features create --product <slug> -n "<name>" -d "<description>" --json` and capture the `id` from the response. Prefer this when the plan covers a single coherent capability inside one product.
- **New epic?** Create one with `exponential epics create -n "<name>" -d "<description>" --workspace <slug|id> --json` and capture the `id`. Prefer this when the work cuts across products or represents a strategic initiative.
- **Standalone tickets?** Skip grouping. Tickets are still tied to a product.

### 4. Draft vertical slices

Break the plan into **tracer bullet** tickets. Each ticket is a thin vertical slice that cuts through ALL integration layers end-to-end, NOT a horizontal slice of one layer.

Slices may be **HITL** or **AFK**. HITL slices require human interaction (architectural decisions, design reviews). AFK slices can be implemented and merged without human interaction. Prefer AFK over HITL where possible.

<vertical-slice-rules>
- Each slice delivers a narrow but COMPLETE path through every layer (schema, API, UI, tests)
- A completed slice is demoable or verifiable on its own
- Prefer many thin slices over few thick ones
</vertical-slice-rules>

For each slice also decide:

- **Ticket type**: `FEATURE` (default for new behaviour), `BUG`, `CHORE`, `IMPROVEMENT`, `SPIKE` (timeboxed investigation), `RESEARCH` (open-ended exploration).
- **Initial status**: `READY_TO_PLAN` for AFK slices that are ready for an agent to grab, `NEEDS_REFINEMENT` for HITL slices that still need a human conversation.

### 5. Quiz the user

Present the proposed breakdown as a numbered list. For each slice, show:

- **Title**: short descriptive name
- **Type**: HITL / AFK
- **Ticket type**: FEATURE / BUG / CHORE / IMPROVEMENT / SPIKE / RESEARCH
- **Blocked by**: which other slices (if any) must complete first
- **User stories covered**: which user stories this addresses (if the source material has them)

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Are the dependency relationships correct?
- Should any slices be merged or split further?
- Are the correct slices marked as HITL and AFK?
- Is the chosen feature/epic grouping right?

Iterate until the user approves the breakdown.

### 6. Publish the tickets

Publish in **dependency order** (blockers first) so you can wire `--by <blocker-id>` to real CUIDs. Use `--json` on every `create` and capture `.id` from the response — that is the CUID you'll reference for dependencies and links.

For each approved slice:

```bash
exponential tickets create \
  --product <slug-or-cuid> \
  --type <FEATURE|BUG|CHORE|IMPROVEMENT|SPIKE|RESEARCH> \
  --status <READY_TO_PLAN|NEEDS_REFINEMENT> \
  --feature <feature-cuid>      # if grouping under a feature
  --epic <epic-cuid>            # if grouping under an epic
  -t "<title>" \
  -b "$(cat <<'EOF'
<body, per template below>
EOF
)" \
  --json
```

After each create, parse the response's `id` and stash it under the slice's number. Then, for each declared blocker:

```bash
exponential tickets block <slice-id> --by <blocker-id>
```

If a slice already has implementation actions queued, link them with `exponential tickets link-action --id <ticket-id> --action <action-id>` — but only if those actions already exist.

Do NOT modify the parent feature, epic, or any pre-existing ticket beyond the dependency edges you add.

### 6a. Leave decision comments where pertinent

If something about how a ticket was framed isn't obvious from its body alone, drop a short comment on the ticket capturing the **why**. The body describes *what to build*; comments are where rationale lives. A future agent (or human) fetching the ticket cold should be able to reconstruct the decisions you made.

Worth commenting:

- **Why this slice was split** off from a larger one ("originally combined with #4 but the auth surface needed its own demo").
- **Why a non-default type/status** was chosen (e.g. `SPIKE` over `FEATURE` because the API shape is unknown; `NEEDS_REFINEMENT` because the user flagged an open question).
- **Why this dependency edge exists** if it isn't structurally obvious from the bodies.
- **Constraints surfaced in the conversation** that didn't fit cleanly in the body (deadlines, stakeholder preferences, prototype findings, ADR pointers).
- **Explicitly-rejected alternatives** the user considered and discarded — so a later agent doesn't re-litigate them.

Not worth commenting: anything already plainly stated in the ticket body or acceptance criteria. Don't narrate the obvious.

```bash
exponential tickets comment --id <ticket-cuid> -b "<short rationale, 1–3 sentences>"
```

Keep comments short and decision-focused. One comment per distinct point, not a wall of text.

### 7. Report back

Print a summary to the user listing each created ticket with its CUID, shortId (if present), and any dependency edges added. If you created a feature or epic in step 3, include its CUID too. Future commands (`exponential tickets show <id>`, `exponential tickets update --id <id> ...`) operate on CUIDs.

### 8. Emit a clean-context execution prompt

End your response with a fenced code block containing a **self-contained prompt** the user can paste into a fresh Claude conversation to start executing the tickets you just filed. The prompt must not rely on any of the current conversation's context — a cold agent reading only this prompt should know exactly what to do.

Include in the prompt:

- One sentence stating the goal: implement the tickets listed below in dependency order.
- The parent feature/epic CUID (if one was created or chosen) so the agent can fetch it for shared context: `exponential features get <cuid>` or `exponential epics get <cuid>`.
- A table or bullet list of every created ticket, in dependency order, with: CUID, shortId, title, type (FEATURE/BUG/...), status (READY_TO_PLAN / NEEDS_REFINEMENT), and HITL/AFK marker.
- Explicit instructions to:
  - fetch each ticket with `exponential tickets get <cuid> --json` before starting it,
  - work tickets in dependency order, starting with `READY_TO_PLAN` AFK tickets that have no open blockers,
  - stop and surface to the human on `NEEDS_REFINEMENT` (HITL) tickets rather than guessing.
- The product slug/CUID so the agent can list siblings if needed.

Do not include conversation-specific narrative (e.g. "we just decided X"). The prompt must read as a standalone work order.

Template:

<execution-prompt-template>
````
You are picking up a batch of tickets just filed in Exponential. Implement them in dependency order.

**Product**: `<product-slug>` (CUID `<product-cuid>`)
**Parent**: <feature|epic> `<cuid>` — fetch with `exponential <features|epics> get <cuid> --json` for shared context.

**Tickets** (dependency order):

| # | CUID | shortId | Title | Type | Status | HITL/AFK | Blocked by |
|---|------|---------|-------|------|--------|----------|------------|
| 1 | <cuid> | <shortId> | <title> | FEATURE | READY_TO_PLAN | AFK | — |
| 2 | <cuid> | <shortId> | <title> | FEATURE | READY_TO_PLAN | AFK | #1 |
| ... |

**How to work**:

1. Run `exponential tickets get <cuid> --json` to load the full body before starting any ticket.
2. Start with `READY_TO_PLAN` + AFK tickets whose blockers are all `DONE`.
3. For each ticket: read body and acceptance criteria, move to `IN_PROGRESS`, implement, verify acceptance criteria, then move to `IN_REVIEW` (or `DONE` if there is no review step).
4. On `NEEDS_REFINEMENT` / HITL tickets, stop and surface the open questions to the human — do not guess.
5. If a ticket's body is ambiguous or contradicts the code, leave a comment with `exponential tickets comment --id <cuid> -b "<question>"` and pause that ticket.
````
</execution-prompt-template>

## Ticket body template

<ticket-template>
## Parent

A reference to the parent ticket, feature, or epic in Exponential (CUID or shortId). Omit if there is no parent.

## What to build

A concise description of this vertical slice. Describe the end-to-end behavior, not layer-by-layer implementation.

Avoid specific file paths or code snippets — they go stale fast. Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it here and note briefly that it came from a prototype. Trim to the decision-rich parts — not a working demo, just the important bits.

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Blocked by

- `<blocker-ticket-cuid-or-shortId>` — short description

Or "None — can start immediately" if no blockers.

</ticket-template>

## Useful commands

```bash
# Discover where to file
exponential workspaces list --json
exponential products list --workspace <slug|id> --json
exponential features list --product <slug|id> --json
exponential epics list --workspace <slug|id> --json

# Create groupings (optional)
exponential features create --product <slug|id> -n "<name>" -d "<desc>" --json
exponential epics create -n "<name>" -d "<desc>" --workspace <slug|id> --json

# Create tickets + wire dependencies
exponential tickets create --product <slug|id> -t "<title>" -b "<body>" \
  --type FEATURE --status READY_TO_PLAN --feature <feature-cuid> --json
exponential tickets block <ticket-cuid> --by <blocker-cuid>

# Inspect what you just made
exponential tickets list --product <slug|id> --feature <feature-cuid> --json
exponential tickets show <ticket-cuid>
```
