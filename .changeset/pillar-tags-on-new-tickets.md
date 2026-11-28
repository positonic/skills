---
"syntro-skills": minor
---

`/to-expo`, `/to-tickets` and `/to-bug` now tag each new ticket with the workspace Pillars it belongs to. They read the Pillars once (`labels list --category pillar`), match each ticket to the Pillars' "What it covers" descriptions, and pass the ids with `--label` on create. The quiz and the bug report show the Pillars chosen. Before this, no skill attached a Pillar, so new tickets were missing from their Pillar page until someone tagged them by hand.
