---
name: grill-with-docs
description: A relentless interview to sharpen a plan or design, which also creates docs (ADR's and glossary) as we go.
disable-model-invocation: true
---

Run a `/grilling` session, using the `/domain-modeling` skill. If this repo tracks work in Exponential (`docs/agents/issue-tracker.md` names an Exponential workspace), also record the decisions as you go, following `EXPONENTIAL-DECISIONS.md` in the `/grilling` skill's directory. Its closing step, where the developer confirms their decisions, comes before the next-step suggestion below.

When we've confirmed shared understanding, suggest the next step on the main chain: for a multi-session build, `/to-prd` — it turns the settled conversation into the human PRD, and the rest of the chain (`/to-robo-prd`, `/to-tickets`, `/implement`) follows from there; for work that fits this session, `/implement` directly. Do not suggest `/to-expo` here: it's the standalone slicer for plans outside the Exponential feature registry, and slicing comes after the PRD either way.
