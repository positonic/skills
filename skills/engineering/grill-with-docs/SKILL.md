---
name: grill-with-docs
description: A relentless interview to sharpen a plan or design, which also creates docs (ADR's and glossary) as we go.
disable-model-invocation: true
---

Run a `/grilling` session, using the `/domain-modeling` skill.

When we've confirmed shared understanding, suggest `/to-prd` as the single next step — it turns the settled conversation into the human PRD, and the rest of the chain (`/to-robo-prd`, `/to-tickets`, `/implement`) follows from there. Do not suggest `/to-expo` here: it's the standalone slicer for plans outside the Exponential feature registry, and slicing comes after the PRD either way.
