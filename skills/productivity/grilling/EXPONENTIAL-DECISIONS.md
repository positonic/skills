# Recording grilling decisions in Exponential

Fork-specific. `/grill-me` and `/grill-with-docs` follow these steps alongside `/grilling`, so the developer's decisions land in Exponential as **their** decisions without anyone opening the app. `/grilling` itself stays generic.

The decisions show on feature and Pillar pages, where people who were not in the session read them, such as a Product Owner. Write each one for that reader. The rules are in [Writing a decision](#writing-a-decision).

## Two identities, one consent

An agent never presents a decision as accepted on its own authority (ADR-0070: agent-created decisions are drafts that only a person can confirm). So two credentials are used, and each writes only what that principal actually did:

| Identity | How | Writes |
|---|---|---|
| **Agent** | `HOME="$EXPONENTIAL_AGENT_HOME" exponential …` (the agent's `exp_agent_…` key) | Logs each question as a draft, links it to the feature, the Pillar and the ticket, and records the developer's answer as it is given |
| **Developer** | plain `exponential …` (the developer's own login) | Only the closing step, and only after an explicit "yes" in chat: confirms the drafts, accepting the answered ones |

### Configuration (once per developer)

- `EXPONENTIAL_AGENT_HOME`: the HOME that holds the agent's key, e.g. `/Users/<dev>/.config/agent-homes/claude`. Check it with `HOME="$EXPONENTIAL_AGENT_HOME" exponential auth status`.
- The developer's normal `exponential auth status` must succeed.
- `exponential-cli` >= 1.22.0 (`decisions create --feature`, `decisions confirm --status`). The Pillar and ticket steps (`decisions create --pillar`, `decisions link --ticket`) were checked on 1.32.0. If `exponential decisions create --help` does not list `--pillar`, upgrade the CLI.

If either identity is missing, say so in one line ("Not recording decisions in Exponential: no agent identity, set EXPONENTIAL_AGENT_HOME") and carry on grilling without recording. **Never fall back to writing the agent's steps as the developer.** That would put the developer's name on things they never confirmed.

## At session start (agent identity)

1. Resolve the workspace and product from the repo, as `/to-bug` does: the **Workspace** and **Product** lines in `docs/agents/issue-tracker.md`, preferring the CUID.
2. Ask once which **feature** the session belongs to, suggesting the repo's **Default feature** if there is one, and offer to create one (`exponential features create …`) if none fits.
3. Ask which **Pillar** and which **ticket** the session belongs to.
   - If `.exponential/current-ticket` exists, it holds the CUID of the ticket in progress. Read that ticket and suggest it, with its Pillar if it shows one:

     ```bash
     HOME="$EXPONENTIAL_AGENT_HOME" exponential tickets get <ticket-cuid>
     ```

   - To show the Pillars the developer can choose from:

     ```bash
     HOME="$EXPONENTIAL_AGENT_HOME" exponential labels list --workspace <ws> --category pillar
     ```

   - If the workspace has no Pillar that fits, ask for a label instead and use `--label` in place of `--pillar` below.
   - If the developer names a scope instead of a ticket, the CLI cannot link it. See the note under [For each question](#for-each-question-agent-identity).
   - The developer can answer "none" to either. Then leave that tag or link out.

Ask steps 2 and 3 as one question, alongside the first grilling question, not as a separate round.

## Writing a decision

A decision has three parts: a **name**, a **statement** and a **body**. The reader was not in the session. Write all three so that reader understands them without the conversation.

### Name

- The name has six words or fewer.
- The name states the outcome, not the topic.

| | Name |
|---|---|
| Bad | Location rules |
| Good | Text place beats Dataminr location |

### Statement

The statement is one sentence, two at most. It says what changes for the product or its users, in plain words.

- It stands alone. Do not use "the flag", "the rule", "option a" or other words that need the session.
- It uses only terms from the project's glossary (`CONTEXT.md`) or the feature's Terms table. Describe anything else in plain words.
- It has no file paths, function names, internal stage names or ticket shorthand.

| | Statement |
|---|---|
| Bad | On locator failure a Dataminr signal drains on its Dataminr point, and a later replay locates it again |
| Good | If CLEAR cannot read the place from the alert text, it publishes the alert at the location Dataminr sent, without delay, and places it again later. |

### Where the name goes

Decisions in Exponential have no `title` field yet (ticket `shy.brook` adds it). Until then, write `--statement` as **"Name: sentence"**. The limit is 500 characters.

```text
If reading fails, publish anyway: if CLEAR cannot read the place from the alert text, it publishes the alert at the location Dataminr sent, without delay, and places it again later.
```

When `exponential decisions create --help` lists `--title`, put the name in `--title` and only the sentence in `--statement`.

### Engineering-only decisions

Some decisions have no effect that a user can see. The name and statement still give the consequence in plain words:

```text
One shared set of location rules: the rules are written once and both pipelines share them.
```

### Body

Write the body in this order:

```markdown
## In plain words

<What was decided and why it matters to users. Two or three sentences. The same rules as the statement.>

## Context

## Options

## Recommendation

## Technical detail

<Files, functions and pipeline stages go here, and only here.>

## Answer

> <the developer's reply, word for word>
```

The `## Answer` section is added when the developer answers. Until then, "In plain words" says what the question is and why it matters to users.

## For each question (agent identity)

Before asking, log it as an open question on the feature, filed under the Pillar:

```bash
HOME="$EXPONENTIAL_AGENT_HOME" exponential decisions create \
  --workspace <ws> --product <product> --feature <feature-id> \
  --pillar "<pillar name, slug or id>" \
  --status OPEN --source AGENT \
  --statement "<the question, one line, in plain words>" \
  --body-file <tmp>/q5.md --json
```

The question follows the [statement rules](#statement) too: it stands alone and has no session words. The body follows the [body layout](#body): "In plain words" first, then the context, the options you're offering and your recommendation with its reason.

Keep the returned `id` and `label`. Use the **id** in every later command, because a draft can't always be looked up by label.

Then link the decision to the ticket:

```bash
HOME="$EXPONENTIAL_AGENT_HOME" exponential decisions link <id> \
  --workspace <ws> --ticket <ticket-cuid>
```

If the link fails, tell the developer in one line and carry on. Do not run it as the developer.

> **Note for the developer: scopes.** The CLI links a decision to a ticket or a feature only (`decisions link --ticket` / `--feature`). It cannot link a decision to a scope until ticket `shy.brook` ships. If the session belongs to a scope and not a ticket, the agent adds the line `Scope: <scope name>` to the "In plain words" section of each body, and you add the link in the app later.

Put the label in the question you ask: **"Q5 (D-0006): …"**.

## For each reply (agent identity)

Sort the reply into one of these:

- **A clear answer.** "Yes" or "agree" to your recommendation, a chosen option, or the developer's own stated answer. Update the decision:
  - `--statement`: the resolved decision as "Name: sentence", following [Writing a decision](#writing-a-decision).
  - `--body-file`: the original body, with "In plain words" rewritten to say what was decided and why it matters to users, plus an `## Answer` section quoting the developer's reply **word for word** in a blockquote, plus any extra instructions it carried. For example, "b, but record a for later" records **b** and adds a note that **a** is wanted later.

  ```bash
  HOME="$EXPONENTIAL_AGENT_HOME" exponential decisions update <id> \
    --workspace <ws> --statement "<Name: sentence>" --body-file <tmp>/q5.md --json
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
   | D-0006 | **If reading fails, publish anyway:** if CLEAR cannot read the place from the alert text, it publishes the alert at the location Dataminr sent, without delay, and places it again later. | "yes" | Accepted |
   | D-0007 | Which countries get the new location rules first? | (hedged) | Open |

   The Statement column shows the name and the plain statement, as recorded.

   Before you show the table, check each row against [Writing a decision](#writing-a-decision):

   - The name has six words or fewer and states the outcome.
   - The statement stands alone, uses only glossary terms, and has no file paths, function names, stage names or ticket shorthand.
   - An open row is a question that stands alone.

   Fix each row that fails with `decisions update` (agent identity), then build the table from the fixed text.

2. Ask once: **"Record these as your decisions in Exponential? (yes / change something)"**. Apply any changes first, with the agent identity, then ask again.

   Ask it **as plain text, as the last line of your message, word for word**. Never ask it through a question tool, popup or multiple-choice prompt (`AskUserQuestion` or similar). A consent hook may be watching for the developer to *type* yes in reply to this exact sentence. An answer picked in a popup reaches you as a tool result, not as something the developer typed, so the hook never sees it and the confirm calls get blocked. Then wait for their next message.
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

If the guard still denies the confirm after a typed yes (consent hook missing, or the reply did not read as a yes), say so in one line and give the developer the exact `exponential decisions confirm …` commands to run in their own terminal; or finish later with `/confirm-decisions`, which is this closing step on its own.

Then suggest the usual next step (`/to-prd`, or `/implement` for work that fits this session).

## Hook note

A hook that blocks unprefixed `exponential` calls (so agent writes can't be misattributed) has to let the closing step through. Gate that on the consent step. Allow only `exponential decisions confirm`, and only after the "yes". Don't lift the block entirely.
