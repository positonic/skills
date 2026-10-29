---
"syntro-skills": minor
---

New `/estimate-points` skill. It gives story points to unestimated Exponential tickets, reading the workspace and product from the repo you're standing in (the same way `/to-bug` does). Every run scores against a fixed rubric and anchor tickets, so estimates don't drift from week to week. A repo can swap in its own anchors in `docs/agents/estimation.md`. It does done tickets by default, planned tickets on request, or named tickets with `--ticket`.
