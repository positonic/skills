---
name: estimate-points
description: Give story points to Exponential tickets that have none — product and workspace resolved from the repo you're standing in, scored against a fixed rubric and anchor tickets so every run scores the same way. Use when the user says "estimate points", "point the tickets", "run the point estimation", "estimate ticket #123", or the Metrics page's Points delivered line is flat because tickets are unestimated.
---

# Estimate points

Unestimated Tickets in, story points out. Retrospective (done work, so the
Metrics page's Points delivered line means something) or forward (planned work).

The defining constraint: **the scale doesn't drift between runs.** The rubric and
anchors are fixed, so a ticket scored next week gets the same points it would
today. If the anchors feel wrong, change them in a file (with the user) — never
recalibrate inside one run.

## Prerequisites

- `exponential auth status` succeeds. If not, tell the user to run `exponential auth login --token <jwt> --api-url <url>` and stop.
- If the repo's `CLAUDE.md` says agents need a `HOME=` prefix on `exponential` calls, put the same prefix on the `python3` commands below — the scripts shell out to `exponential` and inherit `HOME`.

## Process

### 1. Resolve the coordinates from the repo

Exactly as `/to-bug` does: `git rev-parse --show-toplevel`, then read
`<root>/docs/agents/issue-tracker.md` and take **Workspace** and **Product** —
first backticked token is the slug, the second (if present) the CUID; prefer
the CUID. In a worktree where the file is absent, retry from the main checkout
(`git rev-parse --git-common-dir`).

Precedence: a coordinate in the user's sentence beats the file. If neither
gives a product, run `exponential products list --workspace <slug|id> --json`
and ask. **Never guess a product from the folder name** — a near-miss writes
points into someone else's backlog.

### 2. Decide the scope

| User says | Pass to `fetch.py` |
|---|---|
| nothing specific | `--status DONE,DEPLOYED` (default) |
| "planned" / "upcoming" | `--status READY_TO_PLAN,COMMITTED` |
| a ticket ("#123", a CUID, a shortId) | `--ticket <number\|cuid>` (repeatable) |

`--ticket` scores the named tickets even if they already have points (it's a
deliberate re-score); the status scope only ever picks up `points = null`.

### 3. Fetch

```bash
python3 <skill-dir>/fetch.py --workspace <ws> --product <product> [--status … | --ticket …] --out <scratch>/todo.json
```

Prints the count and how many have empty/stub bodies. Zero → say so and stop.

### 4. Load the anchors

If `<root>/docs/agents/estimation.md` exists, its anchors table **replaces** the
default one below (same format) — that's how a repo calibrates to its own
team's past estimates. Otherwise use the defaults.

### 5. Score

≤ 60 tickets: score them yourself. More: split into batches of ~80 and give each
to a subagent with **the Rubric and the active Anchors pasted verbatim**. Every
scorer must:

- read each ticket's **body**, not just its title — a title-only pass changed
  ~70% of estimates on re-check in the first run;
- answer the rubric questions, then snap to the nearest anchor;
- write `{"<ticket id>": points}` covering every input id to `<scratch>/est<n>.json`.

A subagent that reports it skimmed ("mostly from titles", "from body length")
gets sent back to redo the batch.

### 6. Check and apply

```bash
python3 <skill-dir>/apply.py <scratch>/todo.json <scratch>/est*.json --dry-run
python3 <skill-dir>/apply.py <scratch>/todo.json <scratch>/est*.json
```

`apply.py` refuses on missing/unknown ids or off-scale values and prints the
distribution. Compare it with the reference below: a batch with > 20% 1s, or no
5s at all, is suspect — re-score it before applying.

### 7. Report

Count written, the distribution, every 13 (each one is a ticket that should have
been split), and the tickets scored from an empty body (title-only, lowest
confidence).

## Rubric

Points measure **total effort to done** — review, tests and deploy included,
not just code size. Ask, in order:

1. **How many repos / surfaces?** One file or copy → 1. One component or endpoint → 2–3. Front + API, or API + pipeline → 5. Three+ repos or a new subsystem → 8.
2. **New concepts?** Schema change, new entity, new job, ADR → at least 3. Several new concepts or a data-model redesign → 8.
3. **Unknowns?** Spike / research with a written outcome → 3–5 (timeboxed). Root-causing an unknown production failure → 5–8.
4. **Non-code work** (meetings, emails, reviews, inviting users) → 1–2.
5. **13** = a multi-week migration or rebuild that should have been split. Rare; always flagged.

Empty or stub body: score from title + type, take the lower of two candidate
values, and list it as low-confidence.

## Default anchors

Real tickets from the first calibrated run (CLEAR, 2026-10-29). *Team* marks
estimates a human made before the skill existed.

| Pts | Ticket | Why |
|---|---|---|
| 1 | Sign-in shrinks to an orange pill when the sidebar collapses | one CSS fix |
| 1 | Remove heat map on detection page | deletion |
| 1 | CONTEXT.md: add Severity entry linking to an ADR | doc line |
| 1 | Reconnect with IOM | an email |
| 2 | Executive summary Download PDF / View full report buttons do nothing | wire two handlers |
| 2 | Add to Settings page: Mobile Number | one field end-to-end |
| 2 | Fold the version-tag job into the image build job | single CI change |
| 2 | Improve visibility of blockages on maps *(team)* | styling on one layer |
| 3 | Analysis regeneration gate: freshness + 24h floor + force | one rule, several cases, tests |
| 3 | Add events.startedAt — parse event onset from signal text | column + parser |
| 3 | Spike: MapLibre/OSM vs Mapbox streets + roads quality | timeboxed spike + write-up |
| 3 | Global heatmap density band + zoom ladder *(team)* | one map feature |
| 5 | decideImpactPrior, visibility rules and notification fan-out | several rules + fan-out |
| 5 | My requests in the Inbox | new view over a new query |
| 5 | Notion-style event preview sidebar | substantial new UI |
| 5 | GeoJSON ingest / persist from an upstream service *(team)* | cross-system ingest |
| 8 | Dagster OOM: killed step workers brick the run queue | prod root-cause + infra |
| 8 | Modular, selectively-regenerated situation analysis | pipeline redesign |
| 8 | Spanish (es) localization | app-wide |
| 13 | Migrate production infra entirely to a new host | multi-week migration |
| 13 | Resolve the issues causing dev-app to run out of memory *(team)* | open-ended prod investigation |

## Reference distribution

First run (487 done tickets): 1 ≈ 7% · 2 ≈ 23% · 3 ≈ 32% · 5 ≈ 26% · 8 ≈ 11% · 13 < 1%.
A run over similar work should land within a few points of each share.
