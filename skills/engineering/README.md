# Engineering

Skills I use daily for code work.

## User-invoked

Reachable only when you type them (`disable-model-invocation: true`).

- **[ask-matt](./ask-matt/SKILL.md)** — Ask which skill or flow fits your situation. A router over the user-invoked skills in this repo.
- **[grill-with-docs](./grill-with-docs/SKILL.md)** — Grilling session that also builds your project's domain model, sharpening terminology and updating `CONTEXT.md` and ADRs inline.
- **[triage](./triage/SKILL.md)** — Move issues through a state machine of triage roles.
- **[improve-codebase-architecture](./improve-codebase-architecture/SKILL.md)** — Scan a codebase for deepening opportunities, present them as a visual HTML report, then grill through whichever one you pick.
- **[setup-matt-pocock-skills](./setup-matt-pocock-skills/SKILL.md)** — Configure this repo for the engineering skills (issue tracker, triage labels, domain doc layout). Run once per repo.
- **[to-issues](./to-issues/SKILL.md)** — Break any plan, spec, or PRD into independently-grabbable issues using vertical slices.
- **[to-prd](./to-prd/SKILL.md)** — Turn the current conversation into a PRD and publish it to the issue tracker.

## Model-invoked

Model- or user-reachable (rich trigger phrasing so the model can reach for them).

- **[prototype](./prototype/SKILL.md)** — Build a throwaway prototype to answer a design question: a runnable terminal app for state/logic, or several toggleable UI variations.

- **[diagnosing-bugs](./diagnosing-bugs/SKILL.md)** — Disciplined diagnosis loop for hard bugs and performance regressions: reproduce → minimise → hypothesise → instrument → fix → regression-test.
- **[tdd](./tdd/SKILL.md)** — Test-driven development with a red-green-refactor loop. Builds features or fixes bugs one vertical slice at a time.
- **[domain-modeling](./domain-modeling/SKILL.md)** — Actively build and sharpen a project's domain model — challenge terms, stress-test with scenarios, update `CONTEXT.md` and ADRs inline.
- **[codebase-design](./codebase-design/SKILL.md)** — Shared discipline and vocabulary for designing deep modules: small interfaces, clean seams, testable through the interface.
- **[to-expo](./to-expo/SKILL.md)** — Break any plan, spec, or PRD into independently-grabbable tickets in [Exponential](https://www.exponential.im) using vertical slices.
- **[start-ticket](./start-ticket/SKILL.md)** — Start work on an Exponential Ticket: fetch it, transition to `IN_PROGRESS`, check out (or create) its branch, and write the `.exponential/current-ticket` marker.
- **[ship-ticket](./ship-ticket/SKILL.md)** — Ship one Exponential Ticket: commit leftovers, run pre-ship checks, open or extend a PR, link it back to the Ticket, and transition to `QA`.
- **[setup-git-flow](./setup-git-flow/SKILL.md)** — Detect this repo's branching model and persist the resulting Promotion chain to `docs/agents/git-flow.md`.
- **[setup-merge-hook](./setup-merge-hook/SKILL.md)** — Scaffold the GitHub Action that auto-promotes Exponential Tickets to `DONE` on merge to the deploy trigger.
