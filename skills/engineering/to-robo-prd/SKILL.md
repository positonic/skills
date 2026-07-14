---
name: to-robo-prd
description: Append an Agent PRD - the full implementation detail for agents - to the bottom of a feature's PRD page in Exponential. Run after /to-prd (or a human-written PRD) when agents will build the feature.
disable-model-invocation: true
---

This skill writes the **Agent PRD**: the bottom zone of a feature's PRD page, carrying the implementation detail that agents need and humans skim. The top zone (written by `/to-prd` or a human) argues what to build; this zone records how. Do NOT interview the user - synthesize from the conversation and the codebase, and verify every claim against the actual code before writing it down.

`/to-tickets` reads this section to cut the work into tickets and actions - write it so a cold agent could plan from it alone.

## Process

1. **Identify the feature.** From the argument (CUID or name) or the conversation. Fetch it: `exponential features get <id> --json` - read its scopes, requirements, and linked pages.

2. **Find the PRD page.** The feature's linked page titled `PRD: ...` (fetch bodies with `exponential pages get <page-id> --json`). If the feature has no PRD page, stop and tell the user to run `/to-prd` first - the Agent PRD extends an argued case; it does not replace one.

3. **Explore the codebase** until you can name the actual modules, interfaces, and schema objects the work touches. Every implementation decision you write must be checked against the code as it is today - respect ADRs and use the domain glossary's vocabulary. Where the conversation left a decision open, either resolve it from the code or list it explicitly as an open decision; never guess silently.

4. **Write the Agent PRD** using the template below and append it to the page body:

   - Read the current body (`pages get`), append the section, write the whole body back: `exponential pages update --id <page-id> --body-file <path>`.
   - If a `## Agent PRD` section already exists, replace it in place (idempotent re-run) - do not stack a second one.
   - Never modify the human zone above it.

5. **Report back**: page CUID and a one-line summary per Agent PRD section. Suggest `/to-tickets` as the next step.

<agent-prd-template>

## Agent PRD

Machine-facing implementation detail. Humans: the sections above are the readable spec.

### Implementation decisions

The modules to build/modify and the interfaces that change: schema changes, API contracts, state shapes, error handling, specific interactions. Name real modules and procedures as they exist in the code today. Avoid file paths and code snippets that go stale - exception: a snippet that encodes a decision more precisely than prose (state machine, reducer, schema, type shape), trimmed to the decision-rich parts.

### Testing decisions

Where the tests sit (the seams agreed in /to-prd), what good tests look like here (external behavior, not implementation details), and prior art - the existing test files a new test should imitate.

### Scope map

One subsection per registry scope, in rollout order. For each: what exactly it contains, what it explicitly excludes, and its **tracer bullet** - the thinnest end-to-end path through every layer that proves the scope works. This is the primary input /to-tickets uses to cut tickets and actions.

### Constraints & rejected alternatives

Hard constraints (performance budgets, compatibility, migration rules) and the alternatives that were considered and rejected, each with the reason - so a later agent doesn't re-litigate them.

</agent-prd-template>
