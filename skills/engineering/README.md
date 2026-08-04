# Engineering

Skills I use daily for code work.

## User-invoked

Reachable only when you type them (Claude Code: `disable-model-invocation: true`; Codex: `policy.allow_implicit_invocation: false` in `agents/openai.yaml`).

- **[ask-matt](./ask-matt/SKILL.md)** — Ask which skill or flow fits your situation. A router over the user-invoked skills in this repo.
- **[grill-with-docs](./grill-with-docs/SKILL.md)** — Grilling session that also builds your project's domain model, sharpening terminology and updating `CONTEXT.md` and ADRs inline.
- **[triage](./triage/SKILL.md)** — Move issues through a state machine of triage roles.
- **[improve-codebase-architecture](./improve-codebase-architecture/SKILL.md)** — Scan a codebase for deepening opportunities, present them as a visual HTML report, then grill through whichever one you pick.
- **[setup-syntro-skills](./setup-syntro-skills/SKILL.md)** — Configure this repo for the engineering skills (issue tracker, triage labels, domain doc layout). Run once per repo.
- **[close-shipped](./close-shipped/SKILL.md)** — Sweep up after work that landed: remove the worktrees whose branches merged, and promote Exponential Tickets from `QA` to `DONE` once their PR is confirmed merged.
- **[to-prd](./to-prd/SKILL.md)** — Turn the current conversation into the human PRD: a page linked to a Feature in Exponential, with EARS requirements as native rows.
- **[to-robo-prd](./to-robo-prd/SKILL.md)** — Append the Agent PRD (implementation detail, scope map, tracer bullets) to the bottom of a feature's PRD page.
- **[to-tickets](./to-tickets/SKILL.md)** — Turn a feature's Agent PRD into few tickets (default one per scope) with the vertical-slice steps as ordered actions.
- **[implement](./implement/SKILL.md)** — Build the work described by a spec or set of tickets, driving `/tdd` at pre-agreed seams and closing out with `/code-review` before committing.
- **[wayfinder](./wayfinder/SKILL.md)** — Plan a huge chunk of work — more than one agent session can hold — as a shared map of decision tickets on the issue tracker, resolved one at a time until the way to the destination is clear.

## Model-invoked

Model- or user-reachable (rich trigger phrasing so the model can reach for them).

- **[prototype](./prototype/SKILL.md)** — Build a throwaway prototype to answer a design question: a runnable terminal app for state/logic, or several toggleable UI variations.

- **[diagnosing-bugs](./diagnosing-bugs/SKILL.md)** — Disciplined diagnosis loop for hard bugs and performance regressions: reproduce → minimise → hypothesise → instrument → fix → regression-test.
- **[research](./research/SKILL.md)** — Investigate a question against high-trust primary sources and capture the findings as a cited Markdown file in the repo, run as a background agent.
- **[tdd](./tdd/SKILL.md)** — Test-driven development with a red-green-refactor loop. Builds features or fixes bugs one vertical slice at a time.
- **[domain-modeling](./domain-modeling/SKILL.md)** — Actively build and sharpen a project's domain model — challenge terms, stress-test with scenarios, update `CONTEXT.md` and ADRs inline.
- **[codebase-design](./codebase-design/SKILL.md)** — Shared discipline and vocabulary for designing deep modules: small interfaces, clean seams, testable through the interface.
- **[to-expo](./to-expo/SKILL.md)** — Break any plan, spec, or PRD into independently-grabbable tickets in [Exponential](https://www.exponential.im) using vertical slices.
- **[start-ticket](./start-ticket/SKILL.md)** — Start work on an Exponential Ticket: fetch it, transition to `IN_PROGRESS`, check out (or create) its branch, and write the `.exponential/current-ticket` marker.
- **[ship-ticket](./ship-ticket/SKILL.md)** — Ship one Exponential Ticket: commit leftovers, run pre-ship checks, open or extend a PR, link it back to the Ticket, transition to `QA`, then run the review + autofix loop. Merges only with `--merge`.
- **[ship-this](./ship-this/SKILL.md)** — Ship the current working copy end-to-end with zero hand-holding: branch if needed, commit, push, open a PR, wait for the repo's automated reviewer (PR-Agent, CodeRabbit, or local `/pr-review`) and apply its findings, wait for CI, and squash-merge.
- **[setup-git-flow](./setup-git-flow/SKILL.md)** — Detect this repo's branching model and persist the resulting Promotion chain to `docs/agents/git-flow.md`.
- **[setup-merge-hook](./setup-merge-hook/SKILL.md)** — Scaffold the GitHub Action that auto-promotes Exponential Tickets to `DONE` on merge to the deploy trigger.
- **[code-review](./code-review/SKILL.md)** — Two-axis review of the diff since a fixed point: **Standards** (does it follow the repo's coding standards, plus a Fowler smell baseline?) and **Spec** (does it faithfully implement the originating issue/PRD?), run as parallel sub-agents.
- **[resolving-merge-conflicts](./resolving-merge-conflicts/SKILL.md)** — Work through an in-progress git merge or rebase conflict hunk by hunk, resolving by intent traced to each side's primary source, then finish the operation — never `--abort`.
