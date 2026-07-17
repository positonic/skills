# PR URL is the primary Ticket↔PR linkage; commit trailers are best-effort fallback

When the GitHub Action scaffolded by `/setup-merge-hook` promotes a **Ticket** to `DONE` on merge to the **deploy trigger**, it maps the merged pull request back to one or more Tickets using Exponential's `ticket.prUrl` field — set by `/ship-ticket` at PR creation, queried via a new `findByPrUrl` filter on `exponential.tickets.list`. `/ship-ticket` also writes an `Exponential-Ticket: <cuid>` commit trailer for git-archaeology readability, but no automation depends on it.

## Considered options

- **Trailer-as-primary**: parse `Exponential-Ticket:` trailers from merged commits. Rejected because GitHub squash-merges discard per-commit trailers, rebases rewrite them, and the convention depends on every committer (human or agent) using it correctly.
- **Both equally weighted**: Action queries both and merges results without designating one as canonical. Rejected because it doubles the failure surface and obscures which mechanism is the source of truth when they disagree.

## Consequences

- A small SDK + CLI change (workspace-scoped `--pr <url>` filter, plus partial indexes on `prUrl` and `branchName`) must land before the GitHub Action is useful.
- If `ticket.prUrl` is cleared or never set, the Ticket won't auto-promote. Trailers don't rescue this — they exist only for humans reading `git log`.
- Long-term, replacing the personal JWT secret in CI with a scoped service-account token tightens the security posture without changing this ADR.
