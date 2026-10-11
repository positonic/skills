# Recording grilling decisions in Exponential

Fork-specific. `/grill-me` and `/grill-with-docs` follow these steps alongside `/grilling`, so the developer's decisions land in Exponential as **their** decisions without anyone opening the app. `/grilling` itself stays generic.

## Two identities, one consent

An agent never presents a decision as accepted on its own authority (ADR-0070: agent-created decisions are drafts that only a person can confirm). So two credentials are used, and each writes only what that principal actually did:

| Identity | How | Writes |
|---|---|---|
| **Agent** | `HOME="$EXPONENTIAL_AGENT_HOME" exponential …` (the agent's `exp_agent_…` key) | Logs each question as a draft, links it to the feature, and records the developer's answer as it is given |
| **Developer** | plain `exponential …` (the developer's own login) | Only the closing step, and only after an explicit "yes" in chat: confirms the drafts, accepting the answered ones |

### Configuration (once per developer)

- `EXPONENTIAL_AGENT_HOME`: the HOME that holds the agent's key, e.g. `/Users/<dev>/.config/agent-homes/claude`. Check it with `HOME="$EXPONENTIAL_AGENT_HOME" exponential auth status`.
- The developer's normal `exponential auth status` must succeed.
- `exponential-cli` >= 1.22.0 (`decisions create --feature`, `decisions confirm --status`).

If either identity is missing, say so in one line ("Not recording decisions in Exponential: no agent identity, set EXPONENTIAL_AGENT_HOME") and carry on grilling without recording. **Never fall back to writing the agent's steps as the developer.** That would put the developer's name on things they never confirmed.

## At session start (agent identity)

1. Resolve the workspace and product from the repo, as `/to-bug` does: the **Workspace** and **Product** lines in `docs/agents/issue-tracker.md`, preferring the CUID.
2. Ask once which **feature** the session belongs to, suggesting the repo's **Default feature** if there is one, and offer to create one (`exponential features create …`) if none fits. Ask this alongside the first grilling question, not as a separate round.

## For each question (agent identity)

Before asking, log it as an open question on the feature:

```bash
HOME="$EXPONENTIAL_AGENT_HOME" exponential decisions create \
  --workspace <ws> --product <product> --feature <feature-id> \
  --status OPEN --source AGENT \
  --statement "<the question, one line>" \
  --body-file <tmp>/q5.md --json
```

The body holds the options you're offering and your recommendation with its reason. Keep the returned `id` and `label`. Use the **id** in every later command, because a draft can't always be looked up by label.

Put the label in the question you ask: **"Q5 (D-0006): …"**.

## For each reply (agent identity)

Sort the reply into one of these:

- **A clear answer.** "Yes" or "agree" to your recommendation, a chosen option, or the developer's own stated answer. Update the decision:
  - `--statement`: the resolved decision, as one line ("Use Redis for the cache").
  - `--body-file`: the original body, plus an `## Answer` section quoting the developer's reply **word for word** in a blockquote, plus any extra instructions it carried. For example, "b, but record a for later" records **b** and adds a note that **a** is wanted later.

  ```bash
  HOME="$EXPONENTIAL_AGENT_HOME" exponential decisions update <id> \
    --workspace <ws> --statement "<resolved decision>" --body-file <tmp>/q5.md --json
  ```

  The status stays OPEN for now. The developer sets it in the closing step.
- **Not a clear answer.** A hedge, a condition, a question back, or "let me think". Write nothing. Follow up.
- **A fact to verify.** It stays OPEN. Add any evidence you gather to the body.

Rules:

- Only record decisions the developer makes **in this conversation**. A reported decision ("Andi decided X") stays OPEN, with a note saying who reportedly decided it.
- Never record your own recommendation as decided without the developer's reply.

## When a decision also gets an ADR

The Decision Log shows two kinds of entry side by side (ADR-0060): **Decision** rows (`D-0006`), which are written here, and **ADRs**, which are copied in read-only from `docs/adr/` in the repo. Most grilling answers fail the ADR bar and exist only as Decision rows. That is what the Decision rows are for.

When `/grill-with-docs` also writes an ADR for a decision, the decision is one decision with a formal write-up, not two decisions. So:

- Keep the Decision row. It holds the developer's quoted answer, and the ADR is its write-up.
- Add a line to its body: `Formalised as docs/adr/<NNNN-slug>.md (pending merge)`. In the ADR, mention the D-number.
- Once the ADR has merged and synced into the Decision Log, link the two so they show as one ("Decided in"): find the ADR's document id on its Decisions page, then run `exponential decisions update <id> --adr <adr-document-id>`. Syncing doesn't link them on its own yet.

Never log a separate Decision row for an ADR that's already in the repo. Link to it instead.

## Closing step (developer identity, after consent)

When shared understanding is reached:

1. Show one table:

   | D-number | Statement | Recorded outcome | Status to set |
   |---|---|---|---|
   | D-0006 | Use Redis for the cache | "yes" | Accepted |
   | D-0007 | Which region? | (hedged) | Open |

2. Ask once: **"Record these as your decisions in Exponential? (yes / change something)"**. Apply any changes first, with the agent identity, then ask again.
3. On **yes**, run the following as the developer, with **no `HOME=` prefix**:

   ```bash
   # Answered rows: confirm and accept in one command.
   exponential decisions confirm <id> --workspace <ws> --status ACCEPTED --json
   # Open rows: confirm as an open question, so it shows on the feature page.
   exponential decisions confirm <id> --workspace <ws> --json
   ```

   `confirm` also works on a decision that someone already confirmed. Accepting makes the developer its decider, and confirming an open question names no decider.
4. Report the results as a final table: D-number, status, and anything that failed with its error. Don't retry a failure silently.

If the developer says anything other than yes, run nothing as the developer. The drafts stay where they are, visible in their Inbox.

Then suggest the usual next step (`/to-prd`, or `/implement` for work that fits this session).

## Hook note

A hook that blocks unprefixed `exponential` calls (so agent writes can't be misattributed) has to let the closing step through. Gate that on the consent step. Allow only `exponential decisions confirm`, and only after the "yes". Don't lift the block entirely.
