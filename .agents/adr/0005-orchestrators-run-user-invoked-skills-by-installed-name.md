# Orchestrator skills run user-invoked skills by installed name

[`invocation.md`](../invocation.md) sets two rules. A **user-invoked** skill is reachable only by the human typing its name — no other skill can fire it. And dependencies between skills are expressed as `/skill`-style prose invocation, never as `../other-skill/FILE.md` cross-references. The second rule arrived with the file and has no recorded rationale; read in context, it protects four things:

1. **Resolution by name, not layout.** Skills install three ways — symlinked individually into `~/.claude/skills` and `~/.agents/skills`, copied into the Claude plugin, copied by Codex into a cache that drops symlinks ([ADR 0002](./0002-ship-as-a-claude-code-plugin.md)). A repo-relative path only resolves inside this repo's bucket tree and breaks when a skill changes bucket or a user installs a subset. A name resolves through the harness wherever the file lives.
2. **Harness neutrality.** Every skill ships to Claude Code and Codex; a filesystem path binds it to one layout.
3. **Encapsulation.** `SKILL.md` is a skill's interface and its sibling files are implementation. Linking into another skill's internals stops the owner restructuring them.
4. **A real invocation gate.** Routing dependencies through invocation is what lets the harness enforce `disable-model-invocation`. The chain skills are user-invoked because they have side effects — PRD pages and tickets in Exponential, branches, commits, PRs — that a human should consciously trigger.

`/orchestrate-feature` has to run `to-prd`, `to-robo-prd`, `to-tickets`, `start-ticket`, `implement` and `ship-ticket` — all user-invoked. No invocation path exists for it, and the alternatives each break something the rules protect.

## Decision

An **orchestrator** — a skill whose job is to drive a chain of other skills — may run a user-invoked skill by reading its `SKILL.md` at the **installed name** and having an agent follow it. Conditions:

- The orchestrator is itself user-invoked, and its description and body **name the chain it runs**. The human typing the orchestrator is then the conscious trigger for every skill in the chain — one keystroke standing in for several, not the model deciding on its own.
- It resolves each skill **by installed name only**: `~/.claude/skills/<name>/SKILL.md`, else `~/.agents/skills/<name>/SKILL.md`, else a `<name>/SKILL.md` under `~/.claude/plugins/` for a plugin install. Never a repo-relative path. If none exists it stops and names the missing skill.
- Any question a chained skill would put to the human is **relayed, never answered by the agent**. The human-in-the-loop steps that made those skills user-invoked survive the delegation.

The exception is for orchestrators only. A skill that merely wants to use another user-invoked skill still may not; it should invoke a model-invoked one or ask the human to run the step.

## Considered options

- **Flip the chain skills to model-invoked.** Costs permanent context load for six descriptions and reintroduces the autonomous firing the gate exists to prevent. Rejected.
- **Inline the chain's steps into the orchestrator's briefs.** Five second sources of truth that drift from the skills they copy. Rejected.
- **Don't build an orchestrator.** The status quo: the human types the chain by hand, and model-per-phase is impossible because one session runs on one model. Rejected — this is what the orchestrator exists to fix.

## Consequences

- Rules 1–3 are untouched. The installed name is exactly how each harness sees a skill, survives bucket moves, and goes through the `SKILL.md` entry point rather than a skill's internals.
- Rule 4 is bent mechanically and kept in intent. The gate's guarantee becomes "a user-invoked skill fires only when a human types it, or types an orchestrator that names it".
- Orchestrators depend on the skills being **installed**, not merely checked out: `scripts/link-skills.sh` or the plugin must have run. That matches how every other skill reaches its dependencies.
