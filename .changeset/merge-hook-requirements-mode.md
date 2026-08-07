---
"syntro-skills": minor
---

Give `/setup-merge-hook` a mode: promote Tickets, tick feature requirements, or both.

The skill previously did exactly one thing on merge to the deploy trigger — transition linked Tickets `QA` → `DONE`. That's wrong for repos that deliberately keep a human QA gate: they want requirement coverage to track what actually shipped without surrendering the gate. The skill now asks which behaviour(s) to scaffold and writes one self-contained workflow per mode (`exponential-promote.yml`, `exponential-requirements.yml`), so existing repos are unaffected and turning one off is `rm`.

Requirement ticking resolves merged PR → Ticket → `(featureId, scopeId)` → that scope's requirements, and marks each met — never touching Ticket status. Already-met requirements are skipped, so re-runs are idempotent. The semantics are deliberate: a requirement is marked met because its scope's PR merged green, i.e. verified-shipped rather than merely written. That rests on **one ticket = one scope = one PR**; a scope spanning several PRs would have the first merge over-claim the rest, and the generated workflow says so in its own comments.

Both templates now resolve the PR → Ticket link with a client-side `jq` filter on `.tickets[].prUrl` instead of `tickets list --pr`. In exponential-cli 1.0.0 the `--pr` and `--branch` filters are accepted and ignored (identical results filtered or not) and `--pr` errors without `--product` despite its help text — and the old template's `jq '.[].id'` ran against a `{tickets:[…]}` envelope, so it matched nothing either way. Repos already running the scaffolded promote Action have a green workflow that promotes zero Tickets; re-run `/setup-merge-hook` to regenerate it.

The workflow now carries `EXPO_API_URL`, `EXPO_PRODUCT`, and `EXPO_WORKSPACE` in its `env:` block, so the skill captures product and workspace during setup.

`/ask-matt` gains a Precondition entry for `/setup-merge-hook` and `/setup-git-flow`, neither of which the router previously mentioned.
