# mattpocock-skills

## 2.2.0

### Minor Changes

- [#9](https://github.com/positonic/skills/pull/9) [`669ead1`](https://github.com/positonic/skills/commit/669ead16e263ffaaba65dbeb07e41827772be29d) Thanks [@positonic](https://github.com/positonic)! - Add the **`cleanup`** skill — the teardown at the end of a session. It removes the git worktree the work happened in, deletes its branch, promotes that work's Exponential Tickets from `QA` to `DONE`, and closes with an **all-clear**: an explicit statement of whether anything is still in flight, and therefore whether the tab can be closed.

  The gap is real and specific. `/ship-this` and `/ship-ticket` end with a PR merged and nothing else cleared: the worktree is still on disk, the branch is still local, and the Ticket is still in `QA`. `/setup-merge-hook` scaffolds a GitHub Action that handles the Ticket half, but only for repos where it's been wired, and never for the worktrees. Where it hasn't, `QA` becomes a graveyard and `git worktree list` grows past the work actually in flight — and nothing ever tells you a session is finished.

  **Two modes, picked from where you are.** With no flags it runs **here mode**: the worktree you're standing in, and the Tickets belonging to its branch (resolved from the `.exponential/current-ticket` marker, `tickets list --branch`, and `tickets list --pr`, unioned). With `--all` it runs the repo-wide **sweep mode** from the primary checkout. Here mode never removes the worktree it is running inside — git refuses, and forcing it from a parent directory pulls the ground out from under the live session — so it prints the one `cd <primary> && git worktree remove … && git branch -d …` line and says in the all-clear that this is the one thing left.

  **Every action is gated on evidence that the work merged**, which is the whole design. Merge state is read from `gh pr view`, not inferred from a branch looking stale or a Ticket looking done. A `QA` Ticket with no `prUrl` is skipped and reported; one whose PR is `OPEN` stays in `QA`; one whose PR was `CLOSED` without merging is flagged loudly, since that's usually abandoned work filed in the wrong column. `DONE`, never `ARCHIVED` — `ARCHIVED` is triage's `wontfix`, and using it here would misfile shipped work as abandoned.

  **The all-clear is a claim about evidence, not about the run finishing without errors.** It is given only when the PR is `MERGED`, the tree is clean, nothing is unpushed, every Ticket found is `DONE`, and the worktree is gone or its removal command is the only remaining step. Anything short of that prints the outstanding list instead, each item paired with what would clear it. A `--dry-run` never gives it, and neither does a `--tickets-only` / `--worktrees-only` run.

  Worktrees sort into four buckets in sweep mode, and only two are acted on unasked: **prunable** (git already lost the directory) and **landed and clean** get removed; **landed but dirty or with unpushed commits** stops and asks per worktree, showing the actual `git status` output, because `--force` discards that work permanently; **still active** is left alone. The report leads with what was _not_ touched — that list is the one needing a human.

  Three traps are called out in the skill because each silently corrupts a naive sweep. `git status --porcelain` excludes gitignored files, so `dist/` and `node_modules/` don't make a worktree dirty but a modified tracked file does. `git branch --merged` does not list **squash-merged** branches — a squash creates a new commit — so a sweep built on `--merged` alone classifies most modern PRs as unmerged; the PR lookup is primary here and `--merged` only the fallback for branches that never had a PR. And `git log @{u}..` with its error silenced prints nothing and exits 0 on a branch that has **no upstream at all**, which is indistinguishable from a fully-pushed branch — read that way, commits that exist nowhere but this disk classify as clean and the worktree holding them gets removed. The upstream is therefore probed as its own command, unsilenced, and its failure counts as the strongest possible unpushed signal.

  **Wired into the shipping skills.** `/ship-this` gains a step 11 and `/ship-ticket` a step 12, each handing off to `/cleanup` — but only when the final state is actually `merged`. Neither writes the verdict itself; `/cleanup` owns it, because it's only trustworthy derived from evidence that skill gathers. `/ship-ticket`'s default (no `--merge`) does the opposite and states plainly that the work is _in review, not done_, so a shipped-but-unmerged Ticket never reads as finished.

  **Model-invoked**, unlike the `close-shipped` draft it replaces. The hand-off requires it: a user-invoked skill is excluded from the model's reach in every harness, so `/ship-this` and `/ship-ticket` could never actually fire it, and the step would fail silently into exactly the improvised verdict both skills forbid. It's also strictly less consequential than `/ship-this`, which is already model-invoked and squash-merges to the trunk — here mode removes nothing on its own, every irreversible step is gated on a `MERGED` PR, and anything holding uncommitted work stops and asks per worktree.

  Routed in `ask-matt` under Codebase health, listed in the top-level and Engineering READMEs, added to `.claude-plugin/plugin.json`, and wired into `EXPONENTIAL-TEAM.md` at the places that previously said tickets stay in `QA` and you flip them by hand.

- [#551](https://github.com/mattpocock/skills/pull/551) [`697d4ce`](https://github.com/positonic/skills/commit/697d4ce9742da558fd1ba6697c8e9775e2e302dd) Thanks [@mattpocock](https://github.com/mattpocock)! - Add Codex metadata alongside each skill's Claude Code frontmatter so the set works in both harnesses without generated copies.

  - Add an `agents/openai.yaml` beside every `SKILL.md` with Codex UI metadata (`interface.display_name`, `interface.short_description`).
  - Mark every user-invoked skill with `policy.allow_implicit_invocation: false`, the Codex analog of `disable-model-invocation: true`, so Codex excludes it from implicit invocation while explicit `$skill` invocation still works.
  - Document the dual-harness invocation model in `.agents/invocation.md`, `CLAUDE.md`, and the promoted-bucket READMEs.
  - Add `AGENTS.md` as a symlink to `CLAUDE.md` so Codex reads the same repo instructions.

- [#6](https://github.com/positonic/skills/pull/6) [`f651dda`](https://github.com/positonic/skills/commit/f651ddabaaaf57bfd4ae5548e6119f9ccf81b9bd) Thanks [@positonic](https://github.com/positonic)! - Give `/setup-merge-hook` a mode: promote Tickets, tick feature requirements, or both.

  The skill previously did exactly one thing on merge to the deploy trigger — transition linked Tickets `QA` → `DONE`. That's wrong for repos that deliberately keep a human QA gate: they want requirement coverage to track what actually shipped without surrendering the gate. The skill now asks which behaviour(s) to scaffold and writes one self-contained workflow per mode (`exponential-promote.yml`, `exponential-requirements.yml`), so existing repos are unaffected and turning one off is `rm`.

  Requirement ticking resolves merged PR → Ticket → `(featureId, scopeId)` → that scope's requirements, and marks each met — never touching Ticket status. Already-met requirements are skipped, so re-runs are idempotent. The semantics are deliberate: a requirement is marked met because its scope's PR merged green, i.e. verified-shipped rather than merely written. That rests on **one ticket = one scope = one PR**; a scope spanning several PRs would have the first merge over-claim the rest, and the generated workflow says so in its own comments.

  Both templates now resolve the PR → Ticket link with a client-side `jq` filter on `.tickets[].prUrl` instead of `tickets list --pr`. In exponential-cli 1.0.0 the `--pr` and `--branch` filters are accepted and ignored (identical results filtered or not) and `--pr` errors without `--product` despite its help text — and the old template's `jq '.[].id'` ran against a `{tickets:[…]}` envelope, so it matched nothing either way. Repos already running the scaffolded promote Action have a green workflow that promotes zero Tickets; re-run `/setup-merge-hook` to regenerate it.

  The workflow now carries `EXPO_API_URL`, `EXPO_PRODUCT`, and `EXPO_WORKSPACE` in its `env:` block, so the skill captures product and workspace during setup.

  `/ask-matt` gains a Precondition entry for `/setup-merge-hook` and `/setup-git-flow`, neither of which the router previously mentioned.

- [#488](https://github.com/mattpocock/skills/pull/488) [`cdec9f6`](https://github.com/positonic/skills/commit/cdec9f6eb24dbfe606e3ad9b3eb457ba09210b85) Thanks [@mattpocock](https://github.com/mattpocock)! - Reword how the **`prototype`** skill handles its artifacts around a single idea: **the prototype is a primary source**. Rather than being deleted once it's answered its question, the prototype is captured as runnable evidence on a throwaway branch (`prototype/<name>`) out of main, with a context pointer to it left on the implementation issue — so the main branch keeps only the validated decision while the exploration stays findable. The answer (verdict + question) is still captured durably in an issue/ADR/commit.

- [#536](https://github.com/mattpocock/skills/pull/536) [`42a5b70`](https://github.com/positonic/skills/commit/42a5b70fcacc7baff1977b13f3919fb2f63af14e) Thanks [@mattpocock](https://github.com/mattpocock)! - Ship the skill set as a native **Claude Code plugin**. The repo is now its own single-plugin marketplace, so you can subscribe to the promoted skills as a managed, read-only bundle instead of copying editable files:

  ```
  /plugin marketplace add positonic/skills
  /plugin install syntro-skills@syntrofi
  ```

  `.claude-plugin/plugin.json` gains full marketplace metadata (version, description, author, license, keywords) and a sibling `.claude-plugin/marketplace.json` lists the plugin. `skills.sh` remains the universal installer (and the path for Codex and other harnesses today); a native Codex plugin is deferred — see `.agents/adr/0002-ship-as-a-claude-code-plugin.md` for why.

- [#14](https://github.com/positonic/skills/pull/14) [`1317d19`](https://github.com/positonic/skills/commit/1317d1991c8921506b53e63dd3f1bba9d2bef34e) Thanks [@positonic](https://github.com/positonic)! - Teach the ship skills to use **Greptile** as the automated reviewer, and stop them waiting on a **disabled PR-Agent workflow**.

  **Greptile is now the first reviewer `ship-this` probes for**, ahead of PR-Agent, CodeRabbit and a local `/pr-review`. It's a GitHub App with no file in the repo, so detection is by its `Greptile Review` check run on recent PRs' head commits. It wins over PR-Agent because a repo with both has almost always installed Greptile to replace an older PR-Agent workflow.

  The new Greptile path (7b) gates on the **`Greptile Review` check run for the current head SHA completing**, and reads only the inline comments whose `commit_id` is that SHA — older ones describe code that has since changed. The `<!-- greptile_summary -->` comment is edited in place, so as with PR-Agent, "a new comment appeared" is never the signal. P0/P1 findings come first; P2 is advisory.

  **Greptile doesn't review every push** — it reviews the tip of a multi-commit push, and skips some pushes outright (three of the last eight PRs on one repo had no review on their final commit). So the wait has a third outcome besides done and timed-out: no run started within 5 minutes. In round 1 that falls back to `/pr-review`; in round 2 it ends the loop.

  **PR-Agent detection now requires the workflow to be `active`.** Disabling a workflow in the Actions UI leaves the file in `.github/workflows/`, so the old file-only probe picked PR-Agent and burned the full 15-minute timeout on every ship before falling back. `.pr_agent.toml` alone no longer counts either — it configures the action, it doesn't run anything.

  `ship-ticket` delegates to `ship-this` step 7, so only its one-line summary of the probe order changed.

- [#7](https://github.com/positonic/skills/pull/7) [`bd259d8`](https://github.com/positonic/skills/commit/bd259d8770398d9813a401c34fc761fbb0610938) Thanks [@positonic](https://github.com/positonic)! - Teach the ship skills to wait for an automated review, apply its findings, and only then merge.

  **`ship-this`** picked exactly one reviewer — CodeRabbit — and fell back to a local `/pr-review` when it wasn't usable. It now probes for three, in preference order: **PR-Agent** (Qodo), **CodeRabbit**, then `/pr-review`. Detection is by what the repo actually has — `.pr_agent.toml` or a workflow using `qodo-ai/pr-agent`, a `.coderabbit.yaml`, or past reviewer activity on recent PRs. Where both CI reviewers are configured, PR-Agent wins: it's repo-owned CI, so "has the review finished?" has a definite answer, whereas a silent CodeRabbit is indistinguishable from a rate-limited one.

  The new PR-Agent path carries the detail that makes the loop actually work. **Completion is not "a new comment appeared."** Under `persistent_comment = true` PR-Agent _edits its Reviewer Guide comment in place_, so comment counts and timestamps never move and a naive check reads the previous push's review — fixing findings that no longer apply. The reliable gate is the PR-Agent **workflow run for the current head SHA concluding**, with the Code Suggestions comment's HTML SHA stamp (`<!-- 275120e -->`) used to confirm the suggestions describe current code rather than to decide whether to proceed — a clean review may post no suggestions comment at all, and waiting on one hangs forever. Both waits, plus the CI wait in step 8, are specified as **background** jobs so the agent is re-invoked on completion instead of burning a foreground tool call on a poll loop that outlives its timeout. Findings are applied with judgement, not wholesale: `auto_improve` emits a fixed `num_code_suggestions` whether or not that many things deserve changing, so filler is expected and skipped items get reported.

  **`ship-ticket`** had no review step at all — it stopped at "PR open, Ticket → `QA`". It now runs the same loop (step 8), delegating to `ship-this` step 7 rather than duplicating it, with two Ticket-specific notes: in stack mode the reviewer sees other Tickets' commits, and fix commits don't need Ticket trailers. The loop runs _after_ the Ticket is linked and moved to `QA`, so a hung reviewer can't strand a Ticket in `IN_PROGRESS`.

  It also gains an opt-in **`--merge`** (step 9) and `--no-review`. Merging stays off by default: **Ship** and **merge** remain distinct events in the glossary — shipping puts work in review, merging puts it on the Trunk — and `QA → DONE` is still the merge hook's job, never a hand-written transition. Merging a _stacked_ PR under `--merge` prompts for confirmation first, since it lands every Ticket on that PR, not just the one being shipped.

- [#10](https://github.com/positonic/skills/pull/10) [`c85ab57`](https://github.com/positonic/skills/commit/c85ab57945fb411b2a2c99456a00bed91835ce88) Thanks [@positonic](https://github.com/positonic)! - Add the **`to-bug`** skill — one known defect in, one filed `BUG` Ticket out.

  The gap it fills is a shape mismatch. `/to-expo` is the only existing route from "here is a problem" to "here is a ticket in Exponential", and it is built for _plans_: it creates a git worktree, explores the codebase, breaks the input into tracer-bullet vertical slices, quizzes the user on granularity and dependency edges, wires blocking relationships, and emits a cold-start execution prompt. Running all of that to file a single bug you already understand is ceremony with no payoff. `/triage` is not the answer either — it's the inbox side, moving issues that already exist through states. Nothing covered "I just hit this, capture it, I'll keep working."

  **Coordinates come from the repo, not from questions.** The skill resolves `git rev-parse --show-toplevel` and reads `docs/agents/issue-tracker.md` — the file `/setup-syntro-skills` already writes and that `/start-ticket`, `/cleanup`, and `/code-review` already depend on. Those files carry three different shapes in practice (bare slug, `` (`cuid`) ``, and `` (CUID `cuid`) ``), so the parse rule is "first backticked token is the slug, second if present is the CUID", which resolves all three. A coordinate named explicitly in the user's sentence beats the file; the file beats everything else. Where nothing resolves it lists products and asks, and it is told in as many words never to match a product by the repo's folder name — a near-miss files the bug into another product's backlog, where it will not be found again.

  **It never invents a repro.** This is the constraint that shapes the rest. Evidence is taken from the failing output already on screen first, the user's description second, and the code under discussion third — and only for the mechanism, never for the symptom. **Actual** is the real output pasted verbatim and trimmed to the signal, not a paraphrase. Anything unobserved is labelled unobserved, and a suspected cause goes under **Notes** as an explicit hypothesis, because a guess stated as fact sends the next agent chasing the guess instead of the bug. Where a repro genuinely can't be produced, the Ticket says "Not yet reproduced" and is filed `NEEDS_REFINEMENT` — the repo's `needs-info` role — rather than dressed up with steps nobody has run. Reproduced bugs land in `BACKLOG` (`needs-triage`, the documented landing state); `READY_TO_PLAN` requires the user to ask for it, since promoting on the skill's own judgement puts unrefined work in an agent's queue. Missing fields are collected in **one batched question** — sustained questioning is `/grilling`'s job.

  **Priority is set only on a real signal**, from the user or from unmistakable evidence, and left unset otherwise. An invented priority is worse than no priority.

  **The cycle request is capability-probed, not assumed.** Asking for a Ticket "in the current cycle" is the natural way to phrase this, and the platform supports it end to end — a cycle is a `List` row (`listType: SPRINT`, `status: ACTIVE`, with a date range), the `list.list` tRPC route exists, and `cycleId` is typed on ticket create, update, and list-filter in the SDK. The CLI is the missing link: as of v1.10.0 there is no `--cycle` flag on `tickets create`/`update` and no command to enumerate cycles. So the skill runs `exponential tickets create --help | grep -q -- '--cycle'` and branches on the result — passing `--cycle` when it's there, and otherwise filing the Ticket anyway and stating plainly in the report that the cycle must be set in the app. It is explicitly forbidden from hand-rolling an HTTP call to the internal tRPC route to work around the gap. Written as a probe rather than a hardcoded "unsupported", it starts working the day the flag lands with no edit to the skill.

  Also: one search for an existing open `BUG` before creating, so the same defect isn't filed twice; branch, commit, and `file:line` captured on the Ticket, because bugs are commit-sensitive; a quoted heredoc for the body, since bug bodies are full of backticks and `$` that an unquoted one mangles; `branchName` written back after create so `/start-ticket` can rely on the field; and long logs attached as a comment rather than buried in the body above the three fields that matter.

  **Model-invoked**, so "write this up as a bug in Exponential" fires it without a slash command. Routed in `ask-matt` as a fourth on-ramp, with its boundary against both neighbours drawn explicitly — `/diagnosing-bugs` is for when you're fixing it now, `/triage` for issues already filed by someone else — and listed in the top-level and Engineering READMEs and `.claude-plugin/plugin.json`.

- [#538](https://github.com/mattpocock/skills/pull/538) [`2602257`](https://github.com/positonic/skills/commit/260225724133c4a204489599f04642aa089259a0) Thanks [@mattpocock](https://github.com/mattpocock)! - Wayfinder now burns research tickets down with subagents instead of leaving them parked for a separately-launched session.

  Research stays a real ticket type — it's a genuine shared blocker that downstream decisions hang on, and that dependency is exactly what the frontier's blocking edges exist to render. What changes is how it's resolved: because research is AFK, charting doesn't stop and read it. After creating the tickets, the charting session fires a `/research` subagent for each research ticket to burn it down in parallel, capturing the findings on a throwaway `research/<name>` branch with a context pointer. Research tickets are the one exception to _one ticket per session_.

- [#533](https://github.com/mattpocock/skills/pull/533) [`45afd80`](https://github.com/positonic/skills/commit/45afd8074a8b7de5fe073845d080fa9dd6c429fa) Thanks [@mattpocock](https://github.com/mattpocock)! - Add a YAGNI scoping filter to the **`improve-codebase-architecture`** skill's Explore step. Instead of scanning the whole repo evenly, it now scopes to where change is actually landing: if you name a direction it takes it, otherwise it reads the last ~20 commit messages to bias exploration toward actively-developed paths. A deepening opportunity in code nobody touches is a refactor you'll never cash in — the leverage only pays off where you keep editing — so the report stops tidying dormant corners of the repo.

### Patch Changes

- [#535](https://github.com/mattpocock/skills/pull/535) [`e74fee8`](https://github.com/positonic/skills/commit/e74fee89feb6025a6a74f6282feb7d33b1b6e578) Thanks [@mattpocock](https://github.com/mattpocock)! - Make `/ask-matt` clued-up about `/wayfinder` — the heaviest, most cognitively demanding flow.

  The router now sharpens the two routing mistakes people most often make with wayfinder:

  - **Over-reaching for it.** It's slower and denser than a single grill, so it's flagged as the heaviest flow and reserved for the idea that genuinely won't fit one session — a well-scoped feature belongs on `/grill-with-docs`, not here.
  - **Losing the way at the handoff.** When the map clears, wayfinder hands off, it doesn't build: merge onto the main flow at `/to-spec` (which collapses the map's linked decisions into a buildable plan) rather than looping the map straight into `/implement`. Straight-to-`/implement` is only for efforts that turned out genuinely small.

- [#502](https://github.com/mattpocock/skills/pull/502) [`44eed54`](https://github.com/positonic/skills/commit/44eed545186ffd0263e8004867750b80cfddd215) Thanks [@mattpocock](https://github.com/mattpocock)! - Make `/setup-matt-pocock-skills` friendlier and align the local-markdown tracker with the current spec.

  - **Triage labels** are now asked about only when the `triage` skill is installed, and then as a single recommended-yes question ("keep the default triage labels?") instead of an override interrogation. When `triage` isn't installed, the section — and `docs/agents/triage-labels.md` — are skipped.
  - **External PRs as a request surface** is no longer a setup question. The GitHub/GitLab templates still carry the flag, defaulted off; a user can flip it in `docs/agents/issue-tracker.md` later.
  - **Domain docs** default to single-context without asking; multi-context is only offered when the repo shows monorepo signals.
  - **Local-markdown tickets** are now one file per ticket under `.scratch/<feature>/issues/<NN>-<slug>.md` — never a single combined `tickets.md`. `/to-tickets` and the local issue-tracker template now agree, and the spec file is `spec.md` (not `PRD.md`) to match `/to-spec`.

  Docs pages for `setup-matt-pocock-skills` and `to-tickets` re-synced.

- [#532](https://github.com/mattpocock/skills/pull/532) [`170ad48`](https://github.com/positonic/skills/commit/170ad48655825783d0193e850e31a9aac957bb95) Thanks [@mattpocock](https://github.com/mattpocock)! - Reword **`grilling`** for general use. Its description and body no longer scope the interview to a software plan: "this plan" → "this", "enact the plan" → "act on it", and "exploring the codebase" → "exploring the environment". The technique is unchanged; it now reads as a stress-test of any plan, decision, or idea.

- [#534](https://github.com/mattpocock/skills/pull/534) [`7d694b7`](https://github.com/positonic/skills/commit/7d694b7ae981ca221a8f759b15273fe7b5dc393e) Thanks [@mattpocock](https://github.com/mattpocock)! - Name the `/wayfinder` unit a **decision ticket**.

  People kept reading a wayfinder ticket as an ordinary _implementation_ ticket — a slice of a build to execute — when wayfinder uses them as **decision tickets**: questions whose resolution is a decision. The skill description and its opening line now introduce "decision ticket" (and say what makes it one), and the `ask-matt` / engineering README wayfinder blurbs and the docs page match — while "ticket" stays the everyday word once the term is established. `CONTEXT.md` records **Decision ticket** as a domain term so the "avoid: ticket" guidance no longer contradicts wayfinder's deliberate use of the word.

## 1.1.0

### Minor Changes

- [#406](https://github.com/mattpocock/skills/pull/406) [`930a450`](https://github.com/mattpocock/skills/commit/930a450089f77a49af09001d955db8452a4b867d) Thanks [@mattpocock](https://github.com/mattpocock)! - Bring the **`ask-matt`** router up to date with the full skill set. It now maps five skills it was missing: **`tdd`** (woven into the main flow as the red-green engine `implement` drives), **`diagnosing-bugs`** (a new "Something's broken" on-ramp — there was previously no route for a bug), **`domain-modeling`** and **`codebase-design`** (a new "Vocabulary underneath" section), and **`grilling`** (the shared interview primitive). `prototype` is fleshed out as a standalone and the description broadens from "user-invoked skills" to "the skills". A maintenance rule is added to `CLAUDE.md` so any future skill add/rename/remove or flow change triggers an `ask-matt` re-check, beside the existing docs-page re-sync rule.

- [#464](https://github.com/mattpocock/skills/pull/464) [`639df6e`](https://github.com/mattpocock/skills/commit/639df6e7386dfddc739b2aecdeff37a876f2483b) Thanks [@mattpocock](https://github.com/mattpocock)! - Promote and harden **`code-review`**. The in-progress **`review`** skill is renamed to **`code-review`** and moved from `in-progress/` into `engineering/`: it now ships in the plugin, is listed in the top-level and Engineering READMEs (Model-invoked), and has a docs page at `docs/engineering/code-review.md`. The `/implement` skill and docs point at `/code-review`.

  It also gains an always-on **Fowler smell baseline** on its Standards axis — a curated ~12 high-signal "Bad Smells in Code" (Mysterious Name, Duplicated Code, Feature Envy, Data Clumps, Primitive Obsession, Repeated Switches, Shotgun Surgery, Divergent Change, Speculative Generality, Message Chains, Middle Man, Refused Bequest) inlined into `SKILL.md` as a fixed baseline alongside whatever the repo documents, not a new third axis. Two binding rules keep it safe: a documented repo standard overrides the baseline, and every smell is reported as a judgement call, never a hard violation.

- [#464](https://github.com/mattpocock/skills/pull/464) [`639df6e`](https://github.com/mattpocock/skills/commit/639df6e7386dfddc739b2aecdeff37a876f2483b) Thanks [@mattpocock](https://github.com/mattpocock)! - Sharpen **`grilling`** on two fronts.

  **A confirmation gate.** The agent won't enact the plan until you confirm the shared understanding has been reached — turning the skill's existing "shared understanding" completion criterion into an explicit stop-gate. The `description` also recruits the pretrained **`grill`** leading word ("Grill the user relentlessly") to sharpen invocation, and the docs page is re-synced.

  **Facts vs. decisions.** Grilling now splits _facts_ (look them up — explore the codebase) from _decisions_ (put each one to the human and wait for their answer). The old blanket line — "if a question can be answered by exploring the codebase, explore the codebase instead" — was written for the live-human case, but once another skill runs grilling inside a resolve-the-ticket frame it read as license to answer _decisions_ autonomously too. Separating the two keeps a grilling agent from racing ahead and answering its own questions.

- [#463](https://github.com/mattpocock/skills/pull/463) [`af6d692`](https://github.com/mattpocock/skills/commit/af6d6922c3e2b5288eef155346cbe319e4ed3bd0) Thanks [@mattpocock](https://github.com/mattpocock)! - Add two adjacent Steering failure modes to **`writing-great-skills`**, both about how language you think of as "off" still steers the agent. **Negation** — the _elephant_ — is steering by prohibition: naming what _not_ to do drags the forbidden behaviour into context and makes it _more_ available, not less (_don't think of an elephant_), so the cure is to prompt the **positive**. **Negative Space** — the void — is blindness to the steering done by what you leave _out_: every decision a skill declines is delegated to the agent's priors rather than left neutral, so the cure is to read a draft for its silences and decide each omission deliberately (fill it, or leave it open as a real **branch**). Kept as two entries, not one — they carry different diagnostics and different cures — each a full `GLOSSARY.md` entry plus a `SKILL.md` failure-mode bullet, matching how every other failure mode is carried.

- [`850873c`](https://github.com/mattpocock/skills/commit/850873cd73d5f81826ebf512ad35d2b1e113001f) Thanks [@mattpocock](https://github.com/mattpocock)! - Make the **`prototype`** skill model-invoked, so the agent can reach for it autonomously (and other skills can too). Its description is rewritten around the leading word _prototype_ — throwaway code that answers a design question — with one trigger per branch (state/logic sanity-check, or UI exploration).

- [#409](https://github.com/mattpocock/skills/pull/409) [`0d74d01`](https://github.com/mattpocock/skills/commit/0d74d01cbc64ca27778a49b38599f70c534e76a0) Thanks [@mattpocock](https://github.com/mattpocock)! - Add the **`research`** skill — a small, model-invoked skill that spins up a **background agent** to investigate a question against **primary sources** (official docs, source code, specs, first-party APIs), then leaves a single cited Markdown file wherever the repo keeps such notes. It's delegable reading legwork: you keep working while it reads, and get back a document to grill, plan, or design against. Listed in the top-level and Engineering READMEs (Model-invoked), added to `.claude-plugin/plugin.json`, given a docs page at `docs/engineering/research.md`, and routed as a Standalone in `ask-matt`.

- [#469](https://github.com/mattpocock/skills/pull/469) [`a0329ba`](https://github.com/mattpocock/skills/commit/a0329ba95751f58566ed7ab484475917a68f1629) Thanks [@mattpocock](https://github.com/mattpocock)! - Split the **`to-issues`** skill into a lean **Process** and a **Reference** section, and teach it to handle a **wide refactor** — a single mechanical change (like renaming a column) whose **blast radius** fans across the whole codebase, breaking thousands of call sites at once so no vertical slice can land green. The drafting step now points at two co-located reference blocks: the **Vertical slice rules** for ordinary tracer bullets, and **Wide refactors**, which slices the change by **expand–contract** (expand the new form beside the old, migrate call sites in batches sized by blast radius, then contract the old form away) so CI stays green batch to batch — or, when it can't, only at a final integrate-and-verify issue. The issue body template moves into Reference too.

- [#464](https://github.com/mattpocock/skills/pull/464) [`386d4ff`](https://github.com/mattpocock/skills/commit/386d4ff719a7c420ad1454232d0436b01f1b8c17) Thanks [@mattpocock](https://github.com/mattpocock)! - Unify the planning skills. **`to-prd` is renamed to `to-spec`** — "spec" is now the single through-line term (it still opens with "you may know this document as a PRD" for discoverability). **`to-plan` and `to-issues` are merged into one `to-tickets` skill, and `to-issues` is deleted.**

  `to-tickets` breaks a plan, spec, or conversation into a set of **tickets** — tracer-bullet vertical slices, each declaring its **blocking edges**. That one artifact reads two ways depending on the tracker `/setup-matt-pocock-skills` configured: a **local file** (`tickets.md`) writes the edges as text and you work it top-to-bottom by hand; a **real tracker** writes them as native blocking links, so any ticket whose blockers are done is on the frontier and several agents can run at once. The edges live in the ticket either way — the medium only decides whether anything acts on them in parallel.

  Publishing prefers the tracker's **native sub-issues** for parent → slice and **native blocking edges** for `Blocked by` where the tracker supports them, keeping the `## Parent` / `## Blocked by` body sections as the fallback. The "What to build" template points at where a `/prototype`'s code lives rather than inlining a snippet from it.

  `ask-matt`'s main flow now routes `idea → /to-spec → /to-tickets → /implement`, and there are human-facing docs pages at `docs/engineering/to-spec.md` and `docs/engineering/to-tickets.md`.

- [#464](https://github.com/mattpocock/skills/pull/464) [`0557d57`](https://github.com/mattpocock/skills/commit/0557d57579d9b3d39839fdaf8d4a6542b17539ce) Thanks [@mattpocock](https://github.com/mattpocock)! - Settle wayfinder's place in the docs as a **situational on-ramp**, not the new main entry flow — the grill-led _idea → ship_ chain stays the front door (crowning wayfinder as the default spine is a v2-sized move, not a 1.1). The **`ask-matt`** router now names wayfinder's concrete triggers — a greenfield project or a huge feature build, too big for one session — and the two grill front doors (**`grill-me`**, **`grill-with-docs`**) signpost _up_ to wayfinder for the effort that's too big to hold in one session, so the on-ramp is discoverable from where a reader actually starts.

- [#464](https://github.com/mattpocock/skills/pull/464) [`639df6e`](https://github.com/mattpocock/skills/commit/639df6e7386dfddc739b2aecdeff37a876f2483b) Thanks [@mattpocock](https://github.com/mattpocock)! - Graduate and reframe **`wayfinder`** — the skill for planning a huge chunk of work, more than one agent session can hold. It moves out of `in-progress/` into `engineering/` (plugin entry, top-level + Engineering READMEs under **User-invoked**, a docs page at `docs/engineering/wayfinder.md`, and a route in `ask-matt`), landing as a mature skill. The rename and reframe that got it there:

  - **`decision-mapping` is renamed to `wayfinder`**, invoked as `/wayfinder`. "Decision map" was jargony and inaccurate — only one ticket type is actually a decision. The reframe charts a route through a foggy problem instead, giving one coherent leading-word frame — **fog of war**, **frontier**, **the map** — rather than an invented term layered on top.
  - **Destination as the leading word.** Wayfinding finds the _way_ to a destination; it doesn't charge at building it. Naming the destination is the first act of charting — it fixes the scope and shapes every ticket — so the map gains a `## Destination` field every session orients to, and triage pins it before any ticket exists.
  - **Plan, don't do.** The map produces **decisions, not deliverables**; it's done when nothing is left to decide before someone builds the thing. An effort can override this in its Notes.
  - **The map is an index, not a store.** A decision lives in exactly one place — its ticket — so the map only gists and links, never restates; graduating fog into a ticket clears the graduated patch so nothing lingers in two places.
  - **Collaborative by default.** The map moves off a local Markdown file onto the repo's issue tracker: a single `wayfinder:map` issue whose tickets are its child issues — one shared URL the team can watch. Sessions load the map at low resolution and zoom into tickets on demand. Wayfinder stays tracker-agnostic (GitHub, GitLab, local-markdown) behind a pointer in `docs/agents/issue-tracker.md`, and `setup-matt-pocock-skills` seeds the "Wayfinding operations" section.
  - **Claim by assignment, not a label.** A session claims a ticket by assigning it to the driving dev — the assignee _is_ the claim — freeing the label vocabulary to `wayfinder:<type>` alone.
  - **Native blocking.** Blocking prefers the tracker's native dependency relationship, which renders the frontier visually in the tracker's own UI so the human sees what's takeable without opening the map. GitHub and GitLab templates spell out the native recipe, with a body-convention fallback.
  - **Fog vs. out of scope, split.** Two plainly-named map sections — `## Not yet specified` (in-scope fog that graduates as the frontier advances) and `## Out of scope` (work ruled beyond the destination, closed, never graduating) — so beyond-destination work no longer reads as takeable frontier.
  - **A fourth `task` ticket type.** For literal manual work that blocks a decision (provisioning access, moving data, signing up for a service) — the one type that _does_ rather than decides, earning its place by unblocking a decision.
  - **HITL / AFK ticket classification.** Every ticket type is **HITL** (human in the loop — grilling, prototype) or **AFK** (agent alone — research; task is either). A HITL ticket only resolves through the live exchange, so "wait for the human" falls out of the label — a grilling agent that answers its own questions has, by definition, broken HITL. (This fixes students' reports of `/wayfinder` grilling _itself_ instead of the human.)
  - **No-fog early exit restored.** If the opening breadth-first grilling surfaces no fog, the journey is small enough for one session — so it stops and asks how you'd like to proceed rather than building a map nobody needs.

### Patch Changes

- [#464](https://github.com/mattpocock/skills/pull/464) [`639df6e`](https://github.com/mattpocock/skills/commit/639df6e7386dfddc739b2aecdeff37a876f2483b) Thanks [@mattpocock](https://github.com/mattpocock)! - Reshape **`tdd`** into a reference-only skill and add a missing anti-pattern.

  **Reference-only.** The red → green → refactor loop is anchored by leading words the model already holds, so the step-by-step Workflow was largely restating the loop. Dropped the Workflow and per-cycle checklist; folded their one durable idea — vertical slices / tracer bullets — into the Anti-patterns section and a short Rules-of-the-loop list. Introduced **seam** as the leading word for where tests go: test only at pre-agreed seams, confirmed with the user before any test is written. Also dropped the refactor stage — TDD is now red → green; refactoring belongs to the review stage, so the refactor rule and `refactoring.md` moved out (its home is `code-review`).

  **Tautological tests.** Added the tautological-test anti-pattern: a test whose assertion is recomputed the way the code computes it passes by construction and gives zero confidence — distinct from the implementation-coupling anti-pattern already covered. Added as a peer at the same sites: a Philosophy principle (expected values must come from an independent source of truth), a checklist gate, and a BAD/GOOD example pair in `tests.md`.

- [`e00eadb`](https://github.com/mattpocock/skills/commit/e00eadb4bb32c3d5a631ead1a5ed5d6a7c5f74e2) Thanks [@mattpocock](https://github.com/mattpocock)! - Extend the **`triage`** skill to triage external pull requests, treating a PR as an issue with attached code that runs through the same roles and state machine. PRs flow inline alongside issues (gated by a per-repo setup toggle), discovery surfaces only external PRs, the bug-only "reproduce" step is generalized into a single "verify the claim" step, and a redundancy check resolves already-implemented requests to `wontfix` without polluting the out-of-scope knowledge base. `setup-matt-pocock-skills` gains the PRs-as-a-request-surface toggle for GitHub/GitLab.

- [#472](https://github.com/mattpocock/skills/pull/472) [`d869d45`](https://github.com/mattpocock/skills/commit/d869d45afc32beab1c2d1350f8de5e81589512cd) Thanks [@mattpocock](https://github.com/mattpocock)! - Fix **`wayfinder`** hardcoding the issue-tracker doc path, which broke the indirection the rest of the suite relies on.

  `to-issues`, `to-prd`, and `triage` never name a path — they resolve the tracker through the `### Issue tracker` block that `setup-matt-pocock-skills` writes into `CLAUDE.md` / `AGENTS.md`, which points at the tracker doc wherever it lives. Wayfinder instead pinned the literal `docs/agents/issue-tracker.md`, so in a repo that keeps its agent docs elsewhere it silently fell back to the local-markdown tracker — even one whose `CLAUDE.md` clearly declares GitHub issues. It now resolves the doc via that same pointer and reads its "Wayfinding operations" section by name, keeping the indirection consistent across the suite.

## 1.0.1

### Patch Changes

- [`d20ee26`](https://github.com/mattpocock/skills/commit/d20ee2684e2a9442698ac3c1e0f2c5b68c4cf296) Thanks [@mattpocock](https://github.com/mattpocock)! - Make the **`teach`** skill reuse-first. Lessons are now built from reusable **components** in `./assets/` — stylesheets, quiz widgets, simulators, diagram helpers. Reuse is the default: the agent reads `./assets/` before authoring a lesson, builds from what's there, and extracts anything new and reusable into a component rather than inlining it.

## 1.0.0

### Major Changes

- [`47bde84`](https://github.com/mattpocock/skills/commit/47bde84da032afb2e5058f997f3bbca47d321dbd) Thanks [@mattpocock](https://github.com/mattpocock)! - Add the **`ask-matt`** skill — a user-invoked router that points you at the right skill or flow for your situation.

  **Breaking:** `ask-matt` routes over the other user-invoked skills in this repo, so it expects them to be installed.

- [`47bde84`](https://github.com/mattpocock/skills/commit/47bde84da032afb2e5058f997f3bbca47d321dbd) Thanks [@mattpocock](https://github.com/mattpocock)! - Add the shared design skills and rewire existing skills onto them.

  - New **`codebase-design`** skill — the deep-module vocabulary (module, interface, depth, seam, adapter) and the principles for putting a lot of behaviour behind a small interface. The language that previously lived in `improve-codebase-architecture/LANGUAGE.md` now lives here, generalized for reuse across skills.
  - New **`domain-modeling`** skill — actively build and sharpen a project's domain model, stress-testing terms against the glossary and keeping `CONTEXT.md` and ADRs current.
  - `improve-codebase-architecture` now draws its architecture vocabulary from `/codebase-design` and its domain model from `/domain-modeling`.
  - `tdd` now leans on `/codebase-design` for interface-design guidance — its inline `deep-modules.md` / `interface-design.md` notes were removed in favour of the shared skill.
  - `grill-with-docs` now builds the domain model inline via `/domain-modeling`.

  **Breaking:** these skills now depend on the new `codebase-design` / `domain-modeling` skills, so you must install them too.

- [`47bde84`](https://github.com/mattpocock/skills/commit/47bde84da032afb2e5058f997f3bbca47d321dbd) Thanks [@mattpocock](https://github.com/mattpocock)! - Remove the **`caveman`** and **`zoom-out`** skills.

  - `caveman` was a duplicate of another skill I was testing and was never meant to be public.
  - `zoom-out` went unused in practice, so it's been removed from the repo.

  **Breaking:** both skills have been removed.

- [`47bde84`](https://github.com/mattpocock/skills/commit/47bde84da032afb2e5058f997f3bbca47d321dbd) Thanks [@mattpocock](https://github.com/mattpocock)! - Rename the **`diagnose`** skill to **`diagnosing-bugs`**.

  **Breaking:** invoke it as `/diagnosing-bugs` — the old `/diagnose` name no longer exists.

- [`47bde84`](https://github.com/mattpocock/skills/commit/47bde84da032afb2e5058f997f3bbca47d321dbd) Thanks [@mattpocock](https://github.com/mattpocock)! - Replace **`write-a-skill`** with **`writing-great-skills`**.

  - Removed `write-a-skill`.
  - Added `writing-great-skills` (plus its `GLOSSARY.md`) — a reference for writing and editing skills well: the vocabulary and principles that make a skill predictable, hunting no-ops down to the sentence level.
  - Exposed `grilling` as a model-invoked skill — the reusable interview loop behind `grill-me` and `grill-with-docs`.

  **Breaking:** `write-a-skill` has been removed; use `writing-great-skills` instead.

### Minor Changes

- [`47bde84`](https://github.com/mattpocock/skills/commit/47bde84da032afb2e5058f997f3bbca47d321dbd) Thanks [@mattpocock](https://github.com/mattpocock)! - Add the **`resolving-merge-conflicts`** skill — a loop for resolving an in-progress git merge or rebase conflict. Standalone, with no dependencies on other skills.

- [`47bde84`](https://github.com/mattpocock/skills/commit/47bde84da032afb2e5058f997f3bbca47d321dbd) Thanks [@mattpocock](https://github.com/mattpocock)! - Rename the skill taxonomy from **Commands / Skills** to **User-invoked / Model-invoked** across the docs, and add `docs/invocation.md` defining the split: user-invoked skills are reachable only when you type them and exist to orchestrate; model-invoked skills can also be reached automatically when the task fits. A user-invoked skill may invoke model-invoked skills, but never another user-invoked one.

### Patch Changes

- [`47bde84`](https://github.com/mattpocock/skills/commit/47bde84da032afb2e5058f997f3bbca47d321dbd) Thanks [@mattpocock](https://github.com/mattpocock)! - Tighten the **`review`** skill: fail-fast ref check, single-sourced rules, and no-op cuts.
