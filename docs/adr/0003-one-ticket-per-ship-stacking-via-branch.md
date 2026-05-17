# `/ship-ticket` ships one Ticket per invocation; stacking emerges from same-branch reuse

`/ship-ticket` takes at most one **Ticket** CUID per call (auto-detected from `.exponential/current-ticket`, then a branch-name lookup; explicit `<cuid-or-shortId>` arg overrides). To put multiple Tickets on one PR, the developer or agent stays on the same branch and runs `/ship-ticket` a second time after starting the next Ticket; the skill detects the existing open PR via `gh pr view` and appends a commit + links the new Ticket to that PR's URL. Two Tickets shipped onto one branch → two `findByPrUrl` matches → both promoted to `DONE` on merge.

## Considered options

- **Multi-arg (`/ship-ticket A B C`)**: encourages batched shipping that defeats the atomic-commit-per-Ticket value and obscures which work belongs to which Ticket. Rejected.
- **Heuristic auto-stacking** (same feature/epic → stack automatically): introduces fuzzy judgment that doesn't reduce cleanly to a rule, and risks stacking Tickets the reviewer wanted to see separately. Rejected.

## Consequences

- Stacking is opt-in via developer/agent intent (choosing not to branch off trunk), never accidental.
- The marker file at `.exponential/current-ticket` always points at exactly one Ticket — no ambiguity about which Ticket is "active" inside the working tree, even when N are linked to the branch.
- The PR body grows a `Ships: EXPO-N` line per stacked Ticket so reviewers see the full set.
