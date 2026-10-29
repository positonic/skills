---
name: confirm-decisions
description: Confirm agent-drafted Exponential decisions as the developer's own, from the terminal, with a typed yes. Use when the developer says "confirm the decisions", "record those as my decisions", "accept the drafts", when a grilling session ended with unconfirmed D-numbers, or when the closing step of /grill-with-docs or /grill-me could not run.
---

# Confirm Decisions

Agent-drafted decisions (D-numbers with `source: AGENT`, status `OPEN`) become the developer's accepted decisions, without anyone opening the app. The developer types **yes** in chat; the confirm command then runs as the developer, not the agent.

This is the closing step of `/grill-with-docs` and `/grill-me` (see `EXPONENTIAL-DECISIONS.md` in the `/grilling` skill), split out so it can be run on its own: after a session where the step was skipped, blocked, or answered with changes, or whenever a batch of drafts is waiting.

## Why two identities

An agent never presents a decision as accepted on its own authority (ADR-0070 in the Exponential repo). Drafts are written with the agent's key (`HOME="$EXPONENTIAL_AGENT_HOME" exponential …`). Accepting is the only step that runs with the developer's own login, and only after a typed yes. **Never** confirm with the agent identity to get around a blocked command: that records the agent as the decider.

## Prerequisites

- `exponential-cli` >= 1.22.0, with the developer's normal `exponential auth status` succeeding.
- The two hooks in `hooks/` installed in `~/.claude/hooks/` and registered in `~/.claude/settings.json` (see `hooks/README.md`):
  - `exponential-identity-guard.sh` (PreToolUse, Bash) blocks every unprefixed `exponential` call, except `exponential decisions confirm` for 15 minutes after consent in the same session.
  - `exponential-decision-consent.sh` (UserPromptSubmit) writes that consent when the developer's reply opens with a yes-word (`yes`, `ok`, `sure`, `go ahead`, …) and carries no amendment (`but`, `except`, `change`, `not`, …), and the agent's last message ended with the consent question below.

If the guard denies the confirm anyway, say so in one line and give the developer the exact command to run in their own terminal. Do not retry with a prefix.

## Process

1. **Resolve the workspace** from `docs/agents/issue-tracker.md` (the **Workspace** line, preferring the CUID), or from what the developer passed.

2. **Collect the candidates.** In order of preference:
   - The decision ids the developer named, or the D-numbers from this conversation.
   - A feature: `exponential decisions list --workspace <ws> --status OPEN --source AGENT --json` filtered to that feature.
   - Otherwise every `OPEN` + `AGENT` decision in the workspace.

   Fetch each with `exponential decisions get <id> --workspace <ws> --json` (use the agent identity for reads too). `decisions list` does not always return feature-linked drafts; when it comes back empty, fall back to the ids.

3. **Sort each one.** A draft whose body has an `## Answer` section quoting the developer is **answered** and will be set to Accepted. A draft with no answer, a hedge, or a note that someone else reportedly decided it stays an **open question** and is confirmed without a status.

4. **Show one table**, then ask the consent line as plain text, as the very last line of the message, word for word. Never through a question tool or popup: the consent hook watches for the developer to *type* the reply.

   | D-number | Statement | Recorded outcome | Status to set |
   |---|---|---|---|
   | D-0006 | Use Redis for the cache | "yes" | Accepted |
   | D-0007 | Which region? | (hedged) | Open |

   **Record these as your decisions in Exponential? (yes / change something)**

5. **On a typed yes**, run as the developer, with **no `HOME=` prefix**, one call per decision. Answered rows are confirmed and accepted in one command, which makes the developer the decider; open questions are confirmed without a status so they show on the feature page:

   ```bash
   exponential decisions confirm <id> --workspace <ws> --status ACCEPTED --json   # answered
   exponential decisions confirm <id> --workspace <ws> --json                     # open question
   ```

   `confirm` is idempotent on an already-confirmed decision.

6. **On anything but yes**, run nothing as the developer. Apply the requested changes with the agent identity (`decisions update …`), then show the table and ask again.

7. **Report** a final table: D-number, resulting status, and any failure with its error. Never retry a failure silently.

## Example

> **Dev:** confirm the decisions from this morning
> **Agent:** *(fetches D-0023 to D-0036, shows the table)* Record these as your decisions in Exponential? (yes / change something)
> **Dev:** yes record these decisions
> **Agent:** *(runs the confirm command for each)* D-0023 to D-0036 Accepted, you are the decider on all fourteen.
