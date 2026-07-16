# Matt Pocock Skills

A collection of agent skills (slash commands and behaviors) loaded by Claude Code. Skills are organized into buckets and consumed by per-repo configuration emitted by `/setup-matt-pocock-skills`.

## Language

**Issue tracker**:
The tool that hosts a repo's issues — GitHub Issues, Linear, a local `.scratch/` markdown convention, or similar. Skills like `to-tickets`, `to-spec`, `triage`, and `qa` read from and write to it.
_Avoid_: backlog manager, backlog backend, issue host

**Issue**:
A single tracked unit of work inside an **Issue tracker** — a bug, task, spec, or slice produced by `to-tickets`.
_Avoid_: ticket (use only when quoting external systems that call them tickets, or for a **Decision ticket** — see below)

**Decision ticket**:
A `wayfinder` unit — a child **Issue** of a `wayfinder:map` holding a *question* whose resolution is a decision, not a slice of a build to execute. The **decision** qualifier is what keeps it distinct from an implementation ticket; `wayfinder` introduces the term, then uses "ticket".

**Triage role**:
A canonical state-machine label applied to an **Issue** during triage (e.g. `needs-triage`, `ready-for-afk`). Each role maps to a real label string in the **Issue tracker** via `docs/agents/triage-labels.md`.

**Ticket**:
The Exponential-specific manifestation of an **Issue**. Tickets carry additional structure beyond a generic Issue — a CUID, shortId, `branchName`, `prUrl`, and a status from Exponential's `TicketStatus` enum (`BACKLOG`, `READY_TO_PLAN`, `IN_PROGRESS`, `QA`, `DONE`, `DEPLOYED`, …). The terms below — Start, Ship, Stack — operate on Tickets specifically, not arbitrary Issues.

**Start** (verb):
Picking up a `READY_TO_PLAN` **Ticket** and beginning `IN_PROGRESS` work — checking out the branch, writing the `.exponential/current-ticket` marker. Emitted by `/start-ticket`. The front-end bookend to `/ship-ticket`.

**Ship** (verb):
Opening a pull request for a **Ticket**, transitioning it to `QA`, and linking the PR back via `ticket.prUrl`. Emitted by `/ship-ticket`. Distinct from "merge" — shipping puts the work *in review*; merging puts it on the **Trunk**.
_Avoid_: complete, submit, deliver (when referring to PR opening specifically)

**Stack** (verb):
Running `/ship-ticket` for a second **Ticket** while still on the branch of a previously-shipped one. The new commit lands on the same PR; both Tickets link to that PR's URL. For tightly-coupled slices that shouldn't be reviewed independently.

**Promotion chain**:
The ordered list of branches work passes through before reaching the **Trunk** (e.g. `develop → staging → main`). Detected and persisted by `/setup-git-flow` to `docs/agents/git-flow.md`. Skills consume it for base-branch defaults and deploy-trigger detection.

**Trunk**:
The repo's default branch — the final destination of all work in a **Promotion chain**. Usually `main`.

**Deploy trigger**:
The branch whose merge transitions a **Ticket** from `QA` to `DONE`. Almost always equals the **Trunk**. Configured per-repo via `/setup-git-flow`.

**Rollup PR**:
A pull request that promotes work from one branch in the **Promotion chain** to the next (e.g. `develop → main`). Distinct from a feature PR (which targets the first node in the chain). The GitHub Action scaffolded by `/setup-merge-hook` walks rollup PRs' commit messages to find their child feature PRs and the Tickets linked to those.

## Relationships

- An **Issue tracker** holds many **Issues**
- An **Issue** carries one **Triage role** at a time
- A **Ticket** is **Started**, optionally **Stacked**, then **Shipped**; once **Shipped** it moves through the **Promotion chain** via **Rollup PRs** until the **Deploy trigger** is hit, marking it `DONE`
- A **Decision ticket** is an **Issue** (a child of a `wayfinder:map`)

## Flagged ambiguities

- "backlog" was previously used to mean both the *tool* hosting issues and the *body of work* inside it — resolved: the tool is the **Issue tracker**; "backlog" is no longer used as a domain term.
- "backlog backend" / "backlog manager" — resolved: collapsed into **Issue tracker**.
