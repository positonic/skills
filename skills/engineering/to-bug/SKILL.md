---
name: to-bug
description: File one known defect as a BUG ticket in Exponential in a single shot — product and workspace resolved from the repo you're standing in, expected/actual/repro captured from the failing output already on screen. Use when the user says "write this up as a bug", "file a bug in Exponential", "log this as a bug", or wants a defect captured as a ticket without slicing a plan into work.
---

# To Bug

One known defect in, one filed `BUG` Ticket out. No worktree, no interview, no decomposition.

The defining constraint: **this skill never invents a repro.** It files what it can actually see — the failing output in this conversation, the command that just went red, what the user described. Where the repro is missing it says so on the Ticket and files as `NEEDS_REFINEMENT` rather than guessing steps that may not reproduce anything.

Reach for `/to-expo` instead when the input is a plan to break into slices, and `/triage` when the issue is already filed and needs moving through states.

## Prerequisites

- `exponential auth status` succeeds. If not, tell the user to run `exponential auth login --token <jwt> --api-url <url>` and stop.
- A **product** coordinate. Resolved automatically in step 1 — only asked for when it can't be.

## Process

### 1. Resolve the coordinates from the repo

Don't ask for what the repo already knows. Find the checkout root and read its tracker config:

```bash
git rev-parse --show-toplevel
```

Then read `<root>/docs/agents/issue-tracker.md` and parse the coordinate lines. Real files in the wild carry all three of these shapes, so take the **first backticked token** after the label as the slug and the **second, if present**, as the CUID:

```
- **Workspace**: `syntrofi`
- **Workspace**: `syntrofi` (`cmk01wbrb000arzxzj8zy4czg`)
- **Workspace**: `syntrofi` (CUID `cmk01wbrb000arzxzj8zy4czg`)
```

Read **Workspace**, **Product**, and **Default feature** (skip the feature when the line says `none` or `_(none…)_`). Prefer the CUID over the slug when both are present — it survives renames and drops the need for `--workspace`.

Precedence: an explicit coordinate in the user's sentence ("under the `allium` product") beats the file. The file beats everything else.

<coordinate-rules>
- In a git worktree, `--show-toplevel` gives the worktree root — `docs/` is checked out there, so it resolves normally. If the file is genuinely absent there, retry from the main checkout via `git rev-parse --git-common-dir`.
- If no coordinate can be found, run `exponential products list --workspace <slug|id> --json` and ask the user to pick. **Never guess a product by matching the repo's folder name** — a near-miss files the bug into someone else's backlog, and it will not be found again.
</coordinate-rules>

### 2. Check it isn't already filed

One search, not a survey:

```bash
exponential search "<3-5 distinctive words from the symptom>" --workspace <slug|id> --limit 10
```

Search the *symptom*, not your phrasing of it — the error string, the failing function, the endpoint. If an open `BUG` looks like the same defect, show it to the user and ask whether to comment on that one instead of opening a duplicate. Otherwise continue without narrating the check.

### 3. Capture the defect

Fill three fields. Take them from the highest-quality source available, in this order:

1. **Failing output already in this conversation** — a test failure, stack trace, error log, HTTP response, screenshot. Best source; use it verbatim.
2. **What the user just described.**
3. **The code under discussion** — for the mechanism, never for the symptom.

<capture-rules>
- **Actual** is the real output, pasted in a fenced block and trimmed to the signal. Not a paraphrase.
- **Expected** is the specific behaviour that should have happened, not "it should work".
- **Repro** is a runnable command or a numbered click-path. "It breaks sometimes" is not a repro — it's a missing one.
- Anything you did not observe is labelled as unobserved. A suspected cause goes under **Notes** as a hypothesis, never stated as fact — a later agent will otherwise chase your guess instead of the bug.
</capture-rules>

If a field is missing and can't be inferred, ask **one batched question** covering all the gaps at once. One round trip. This is a capture tool — sustained questioning is `/grilling`'s job, not this skill's.

Also grab the environment, because bugs are commit-sensitive:

```bash
git rev-parse --short HEAD && git branch --show-current
```

### 4. Write the title and body

The title is **symptom-first**, not a fix instruction — `<what breaks> when <condition>`, around 70 characters. "Ticket list returns 500 when the product slug has a trailing space", not "Fix ticket list".

<ticket-template>
## Expected

<the specific behaviour that should have happened>

## Actual

```
<verbatim failing output, trimmed to the signal>
```

## Repro

1. <runnable command or click-path>
2. …

Or: `Not yet reproduced — <what was observed instead, and where>.`

## Environment

- Repo `<repo>` — branch `<branch>`, commit `<short-sha>`
- Surfaced at `<file:line>` (if known)

## Notes

<suspected cause, explicitly flagged as a hypothesis. Omit the section if you have none.>
</ticket-template>

Keep the body tight. If the raw log runs long, put a trimmed extract in **Actual** and attach the full thing as a comment in step 7 — a wall of stack frames in the body buries the three fields that matter.

### 5. Choose type, status, and priority

**Type** is `BUG`. If the evidence says otherwise — a missing capability rather than broken behaviour — say so and file `FEATURE` or `IMPROVEMENT` instead rather than mislabelling it.

**Status** follows what you actually established:

| Situation | Status | Triage role |
|---|---|---|
| Reproduced, or the failing output is right there | `BACKLOG` | needs-triage |
| Not reproduced — symptom reported but unconfirmed | `NEEDS_REFINEMENT` | needs-info |
| Reproduced *and* the user says to queue it for an agent | `READY_TO_PLAN` | ready-for-agent |

`BACKLOG` is the default landing state. Don't promote to `READY_TO_PLAN` on your own judgement — that puts unrefined work in an agent's queue.

**Priority** (`--priority`, 0–4, lower is more urgent) is set **only on an explicit signal** from the user or from unmistakable evidence. Leave it unset otherwise; an invented priority is worse than none.

- `0` — data loss, production down, security
- `1` — core flow broken, no workaround
- `2` — broken, workaround exists
- `3` — minor or cosmetic
- `4` — trivial

### 6. Cycle — probe before promising

The user will often ask for the Ticket to land **in the current cycle**. Check whether the installed CLI can do that before claiming it did:

```bash
exponential tickets create --help | grep -q -- '--cycle' && echo cycle-supported
```

- **Supported** — resolve the current cycle (the `ACTIVE` one whose date range covers today) and pass `--cycle <id>` on create.
- **Not supported** — as of CLI v1.10.0 it is not. The data model, tRPC API, and SDK all carry `cycleId`, but the CLI exposes no `--cycle` flag on `tickets create`/`update` and no command to list cycles. File the Ticket without it and tell the user plainly in step 8 that the cycle must be set in the app. Do **not** hand-roll an HTTP call to the internal tRPC route to work around this.

### 7. Create it

```bash
exponential tickets create \
  --product <slug-or-cuid> \
  --workspace <slug-or-cuid>       # required when --product is a slug
  --type BUG \
  --status <BACKLOG|NEEDS_REFINEMENT|READY_TO_PLAN> \
  --priority <0-4>                 # only if step 5 set one
  --feature <feature-cuid>         # only if the repo declares a default feature
  -t "<title>" \
  -b "$(cat <<'EOF'
<body, per the template in step 4>
EOF
)" \
  --json
```

Use the quoted heredoc (`<<'EOF'`) — bug bodies are full of backticks, `$`, and quotes that an unquoted one will mangle.

Capture `id` and `shortId` from the JSON, then set the branch name so `/start-ticket` can rely on the field being present:

```bash
exponential tickets update --id <cuid> --branch "<shortId-lowercased>-<slug(title)>"
```

Slug rules: lowercase, non-alphanumeric runs to `-`, trim leading/trailing `-`, cap at 50 chars. `EXPO-42` + "Ticket list returns 500 on trailing space" → `expo-42-ticket-list-returns-500-on-trailing-space`.

If the create fails on an unknown product, fall back to `exponential products list --json` and ask — don't retry with a guess.

### 8. Attach the long evidence, then report

If you trimmed a log, attach the full one now:

```bash
exponential tickets comment add --id <cuid> -m "<full log in a fenced block>"
```

Then report, in a few lines:

- `shortId` — title
- Product, status, priority (or "unset")
- Whether it was reproduced, stated explicitly
- **If the cycle was requested but unsupported**: say it was not set, and that it needs setting in the app. Never let this pass silently — the user asked for it.
- Next step: `/start-ticket <shortId>` to pick it up, or `/triage` to route it.

## Failure modes

- **No `docs/agents/issue-tracker.md`** — ask for the product. Don't infer it from the folder name.
- **CLI not authed** — surface `exponential auth login` and bail before writing anything.
- **The "bug" is a support question** — a misunderstanding of intended behaviour is not a defect. Say so and don't file; a wrong ticket costs someone a triage pass.
- **Cycle requested, CLI can't set it** — file the Ticket anyway and report the gap. Filing nothing is the worse outcome.
- **Several distinct defects in one report** — file the one that's reproducible, and list the others in the report for the user to confirm before opening more.
