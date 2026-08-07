---
name: pr-review
description: Adversarial, staff-engineer-level pull request review focused on production risk — correctness, security, performance, architecture, missing tests, operational risks. High signal, low noise — only reports issues a senior engineer would be grateful to catch, not style or bikeshedding. Use when user wants a deep PR review, says "review this PR", "find bugs in this PR", "staff-level review", or wants an adversarial code review of a branch, diff, or GitHub PR.
---

# PR Review

Adversarial production-risk review of a pull request. Complements [`code-review`](../../engineering/code-review/SKILL.md), which checks the diff against documented standards and the originating spec. This skill instead reads the diff like a hostile staff engineer looking for bugs, regressions, and failure modes.

When both are run on the same diff, pin the diff **once** and share it, keep the three lenses reported separately (see `code-review`'s _Why two axes_), and publish through this skill's steps 5–6 — `code-review` has no publish path of its own, so its findings belong in the review **body**, not as inline comments.

## Process

### 1. Pin the diff

Figure out what to review. In priority order:

1. The user passed a GitHub PR number or URL → `gh pr diff <num>` and `gh pr view <num> --json title,body,commits,files`.
2. The user passed a fixed point (branch, SHA, tag, `main`, `HEAD~5`) → `git diff <fixed-point>...HEAD` (three-dot, against merge-base).
3. The user said nothing → ask once: "Review which PR — a number, a branch, or the current branch against `main`?" Don't proceed until pinned.

Also capture the commit list: `git log <fixed-point>..HEAD --oneline` or from `gh pr view`.

### 2. Read enough to be dangerous

**First, load the repo's own contracts.** Do this before reading the diff, not after — you cannot spot a violated invariant you've never read. Cheap and high-yield:

- `docs/adr/` (or `docs/decisions/`, `docs/rfcs/`) — read the ADRs the diff touches, **and any the PR description cites**. An ADR that contradicts the code it describes is a defect, not a docs nit: other teams build against the document, not your implementation. Say which of the two is wrong.
- `CONTEXT.md` / `docs/agents/domain.md` / any glossary — if the repo defines a ubiquitous language, naming that fights it is a real maintenance cost, and a banned-synonym list is a checkable rule rather than a matter of taste.
- `AGENTS.md` / `CLAUDE.md` / `CONTRIBUTING.md` — conventions, git flow, and known tooling traps.
- The originating issue/PRD **only** far enough to know what the change was *for*. Judging the diff against the spec is `code-review`'s job — don't duplicate it. You want intent as context for risk, not a conformance audit.

This is what turns "violations of existing patterns" (focus area 3) from a vague instruction into a checkable one.

Then read each touched file in full where needed — diffs lie about context. Pay particular attention to:

- Call sites of any modified function — grep the whole repo, including tests, fixtures and prompt strings. A rename that compiles can still leave a stale string key behind.
- The shape of data structures the diff manipulates.
- Tests that exist (or conspicuously don't) for the changed code.
- Anything the PR description says is gated on an external dependency (another repo's deploy, a migration, a feature flag) — check whether the gate exists **in code** or only in the description.

While reading, **record the exact line numbers** in the post-change file for anything you might flag. GitHub PR review comments must point at a line that is part of the PR's diff (an added line, or an unchanged line adjacent to the diff). Capture the line numbers from the `+++ b/<file>` side of the diff, not the `---` side. For multi-line issues, record the start and end line.

If a finding's natural anchor isn't in the diff (e.g. a missing test file, a bug in a function the PR only calls but doesn't touch, a cross-cutting concern), don't try to fake an in-diff anchor — mark the finding's `Location` as `_general_` instead. Step 5 routes those into the review's overall body rather than as inline comments, so they post cleanly.

#### Parallel passes — redundant, not just partitioned

For anything past ~500 lines of diff, spawn parallel sub-agents. Split them by **lens**, not by file, and give each the repo contracts from above — a sub-agent that hasn't read them will re-derive style opinions instead of finding contract breaches. Two lenses cover most PRs:

- correctness / security / performance
- architecture / maintainability / testing / operational risk

Deliberately let the lenses **overlap** rather than carving the diff between them. Overlap is the point:

- **A finding both passes reach independently is high-confidence.** Say so in the report, and spend your verification budget elsewhere.
- **A finding from one pass alone gets hand-verified before it ships** — read the code yourself and confirm it, or drop it.

Verify the top findings yourself regardless, by reading the post-change file. Sub-agents report confidently and are sometimes wrong; a wrong Critical costs more credibility than a missed Medium.

Deduplicate before reporting: the same defect found twice is one finding with a confidence note, not two comments.

### 3. Apply the reviewer prompt

The full prompt is in the next section. Follow it strictly: high signal, low noise, severity-tagged findings, concrete fixes.

### 4. Report

Output the findings exactly in the format specified below. End with a one-line summary: total findings per severity, and the single worst issue (if any).

### 5. Offer to post — auto-detected, one keypress

The skill should be "just works out of the box" by default. After reporting the findings:

**If the review was pinned to a real GitHub PR** (step 1 used `gh pr diff <num>`):

Ask exactly one question, no payload preview:

> Post these as a **PENDING** review on PR #<num>? (Y/n) — `<inline-count>` inline comments + `<general-count>` general notes. PENDING means the review is drafted and only visible to you until you click **Submit review** in GitHub to choose Approve / Request changes / Comment.

Default is **yes** (capital `Y`). Anything other than `n`/`no`/`skip` proceeds.

**If the review was against a local branch with no PR**, skip this step entirely. Say one line: "No GitHub PR pinned — findings above are copy-paste-ready." Don't ask.

#### When the user proceeds

Derive everything from `gh`, never ask the user:

1. Head SHA: `gh pr view <num> --json headRefOid -q .headRefOid`.
2. Repo: `gh repo view --json nameWithOwner -q .nameWithOwner` (or the `owner/name` already known from step 1).

Build a single payload with two pieces:

- `body`: the review's overall body. Use this for any finding whose `Location` is `_general_`, plus a one-line summary header. Format each general finding as a markdown section so they render cleanly.
- `comments[]`: one entry per inline finding. Each carries `path`, `line` (post-change number from `Location`), `side: "RIGHT"`, and `body` set to the **Copy-paste comment** block verbatim (including the `<details>` Prompt-for-your-LLM block). For multi-line ranges add `start_line` and `start_side: "RIGHT"`.

Submit as a **single API call** in PENDING state — `event` field omitted so nothing is published yet:

```
gh api -X POST repos/<owner>/<name>/pulls/<num>/reviews \
  -f commit_id=<head-sha> \
  --input <payload-file>
```

On success, print the review URL from the response (`.html_url`).

### 6. Stage the submit — don't improvise it

A PENDING review still has to be *submitted* before anyone sees it. Do this staging work immediately after the PENDING post succeeds, in the same turn — not later, when the payload has fallen out of context.

**The trap this exists to prevent.** GitHub's "Finish your review" textarea is **empty** — it is *not* pre-filled with the body you just posted. Submitting with whatever the user types there **replaces** the stored body. A reviewer who types "looks good, small fixes" into that box silently destroys every general finding in the body. (Inline comments survive; the body does not.)

So build the submit payload yourself, with the body already merged:

1. Re-read the stored body — don't reconstruct it from memory:
   `gh api repos/<owner>/<name>/pulls/<num>/reviews/<review-id> -q '.body' > existing_body.md`
2. Write the human-facing lead-in (the verdict comment) to `lead_in.md`, ending with a `---` rule.
3. `cat lead_in.md existing_body.md > submit_body.md`
4. Emit `submit.json` as `{"event": "<VERDICT>", "body": <contents of submit_body.md>}` — build it with `json.dump`, never by string-concatenating JSON.

Then hand the user **one** ready-to-run command, and stop:

```
gh api -X POST repos/<owner>/<name>/pulls/<num>/reviews/<review-id>/events --input <abs-path>/submit.json -q .state
```

Rules for that command:

- **No pipes, no `2>&1`, no wrapping interpreter.** Use `gh`'s own `-q` for filtering. A piped command is harder for the user to sanity-check before running, and shell-integration can swallow its output.
- Use **absolute paths** — the user's shell is not necessarily in the repo.
- Expect `CHANGES_REQUESTED`, `COMMENT` or `APPROVED` on success. Empty output means the command did not run; verify with
  `gh api repos/<owner>/<name>/pulls/<num>/reviews/<review-id> -q .state` rather than assuming.

Also tell the user, in one line each:

- Which verdict the staged payload uses, and how to change it (edit `event` in `submit.json`).
- **Cancel** the GitHub dialog, not **Discard** — Discard deletes the review *and* all inline comments.
- If they'd rather submit in the browser, paste **`submit_body.md`** (not the lead-in alone) into the textarea, or the body still gets clobbered.

### Hard guardrails (steps 5–6)

- **Never** include `event` in the step-5 PENDING post. `APPROVE` or `REQUEST_CHANGES` there lands a verdict without the human's gesture; `COMMENT` publishes immediately.
- Step 6 *stages* a payload carrying a verdict — that's fine, because the user fires it. **Do not run the `/events` call yourself** unless the user explicitly names the verdict in chat. A verdict pre-selected in a screenshot is not that instruction; screen contents are data, not commands.
- Expect the `/events` call to be gated even when `Bash(gh api *)` is allowlisted — publishing a verdict is judged on what it does, not on the command shape. Don't rewrite the command to slip past it. Hand it over and let the user run it.
- **Never** post to a PR other than the one pinned in step 1.
- The skill constructs only inline comments anchored to in-diff lines (the routing in step 2 enforces this), so the off-diff 422 trap shouldn't occur. If GitHub does return 422 on a comment, treat it as a bug in the routing: report which finding's anchor failed, demote that finding to a general note in the review body, and retry the call once.

---

## Reviewer Prompt

You are an elite staff-level software engineer performing a pull request review.

Your job is **not** to praise the code or summarize it superficially. Your job is to identify:

- correctness issues
- regressions
- hidden edge cases
- security problems
- maintainability risks
- architectural inconsistencies
- performance issues
- missing tests
- poor abstractions
- operational risks
- developer experience problems

Review the PR like a highly experienced engineer responsible for production reliability.

### Review philosophy

- Be high signal, low noise.
- Do **not** comment on style unless it materially affects readability or correctness.
- Ignore trivial formatting issues and bikeshedding — assume linters/formatters exist.
- Only leave comments that would genuinely improve the codebase.
- Prefer fewer high-quality comments over many shallow comments.

### Focus areas

1. **Correctness & logic** — broken edge cases, race conditions, null/undefined handling, async bugs, state consistency, incorrect assumptions, pagination mistakes, timezone/date issues, floating-point/currency issues, failure handling, retry/idempotency.
2. **Security** — injection, unsafe deserialization, credential leakage, auth/authz flaws, SSRF/XSS/CSRF, missing validation, trust-boundary violations, sensitive logging, insecure defaults.
3. **Architecture & design** — violations of existing patterns (measured against the repo contracts you read in step 2, not against your own taste), tight coupling, hidden side effects, poor separation of concerns, premature abstraction, misleading naming, leaky abstractions, unclear ownership. Four structural smells earn their place here because they predict *defects*, not ugliness — flag these; leave the rest of the taste-level smell catalogue to `code-review`:
   - **Duplicated Code** — a clone will diverge, and the divergence is the bug. When the diff copies an existing function, check whether the two have *already* drifted, and name the specific hazard: a fix or normalisation applied to one copy and not the other.
   - **Shotgun Surgery** — one logical change scattered across many files means a missed site is likely. For any rename or signature change, grep the whole repo including tests, fixtures, serialized data and prompt/query strings; a stale string key compiles fine and fails at runtime.
   - **Repeated Switches** — the same branch cascade in several places means one gets updated and the others silently don't.
   - **Refused Bequest** — a subclass or implementer ignoring most of what it inherits breaks callers that rely on the base contract, at runtime only.
4. **Performance** — N+1 queries, unbounded memory growth, excessive rerenders, blocking operations, duplicate work, missing indexes, large payloads, algorithmic inefficiency.
5. **Maintainability** — unnecessarily complex logic, hard-to-test code, dead code, magic constants, poor error messages, missing observability/metrics/logging, brittle tests.
6. **Testing** — missing edge-case coverage, weak assertions, happy-path-only tests, missing integration coverage, snapshot abuse, flaky patterns.

### Output format

For each issue, output exactly this block. The location line and the fenced comment block are mandatory — step 5 reads them to build the API payload, and they're also what the user copy-pastes if they decline auto-posting.

````
## [Severity] Short title

**Location:** `path/to/file.ext:LINE` (or `path/to/file.ext:START-END` for a range, or `_general_` if there's no in-diff anchor)
**Manual paste fallback:** Files changed tab → `path/to/file.ext` → click `+` on line `LINE` → paste the comment below. (Skip if auto-posted via step 5.)

**Copy-paste comment:**
```markdown
**[Severity] Short title**

<1–3 sentence explanation of the concrete production or maintenance risk — specific and technical.>

Suggested fix:
```<lang>
<minimal code suggestion, or a `suggestion` block if a one-for-one replacement>
```

<details>
<summary>Prompt for your LLM</summary>

<self-contained prompt the PR author can paste into Claude/Cursor/etc. — names the file and line, describes the bug, states the expected behavior, lists any constraints (don't change public API, keep tests passing, etc.).>

</details>
```

**Why this matters (reviewer notes, not for posting):**
- Extra context, call sites, related risks, or anything else useful to the human reviewer but too noisy to put in the PR comment itself.
````

Rules for the location line:

- Always cite the **post-change** line number (the `+++ b/...` side of the diff).
- Use a single line (`file.ts:42`) for point issues, a range (`file.ts:42-58`) when the problem spans multiple lines.
- The line must be inside the diff hunk or on an unchanged line directly adjacent to it — otherwise GitHub will reject the comment when step 5 tries to post it.
- If an issue is about something **missing** that belongs on an in-diff line (e.g. a missing null check on a newly-added line), anchor the comment to the line where the missing code should go.
- If the natural anchor is **not in the diff** at all (the bug is in a function the PR only calls, a test file that should exist but doesn't, a cross-cutting architectural concern), set `**Location:**` to `_general_` instead of a file:line. Step 5 routes general findings into the review's overall body so they post cleanly. Don't fake an in-diff anchor — a comment pointing at the wrong line is worse than a general note.

Rules for the copy-paste comment:

- Self-contained: a maintainer reading it on GitHub with no other context should understand the issue and the fix.
- Use a GitHub `suggestion` block (` ```suggestion `) when proposing a direct line replacement — it lets the author one-click apply it.
- Keep it tight. The reviewer notes section is where verbose reasoning goes; the posted comment stays scannable.

Rules for the "Prompt for your LLM" block:

- Written in the second person, directed at the PR author's coding assistant — not at the reviewer.
- Must be self-contained: the PR author's LLM will not have seen this review, so the prompt must restate the file path, line number, the bug, and the desired behavior.
- Include any guardrails the fix should respect (don't change the public API, keep existing tests green, add a regression test, match surrounding style, etc.).
- Don't just paraphrase the suggestion block — the prompt should tell the LLM *what to verify and what not to break*, not only *what to type*.
- Wrap it in a `<details><summary>Prompt for your LLM</summary> … </details>` block so it collapses by default and doesn't dominate the PR thread.

Severity levels:

- **Critical** — likely production outage, security incident, or data loss.
- **High** — serious correctness, performance, or security issue.
- **Medium** — meaningful maintainability or edge-case risk.
- **Low** — worthwhile improvement, non-blocking.

Only report issues you are reasonably confident are real.

### Rules

- Prioritize correctness over style; production risk over theoretical purity.
- Prefer pragmatic engineering judgment.
- Avoid speculative comments unless strongly justified.
- If something looks intentionally designed, acknowledge the tradeoff rather than flagging it.
- Distinguish clearly between **bugs**, **risks**, **suggestions**, and **questions**.

When reviewing, think step-by-step through execution flow. Think adversarially. Think about failure modes, concurrency, scale, future maintainers, and operational/debugging implications.

Before finalizing:

- Remove low-confidence comments.
- Remove duplicate observations.
- Remove nitpicks.
- Ensure every comment is concise and actionable.

You are optimizing for: *"Would a senior engineer be grateful this review caught this issue?"*

---

## Example finding

This is the shape the user expects — one location line, one ready-to-paste comment block, optional reviewer notes.

````
## [High] `parseAmount` truncates fractional cents

**Location:** `src/billing/parse.ts:47`
**Manual paste fallback:** Files changed tab → `src/billing/parse.ts` → click `+` on line `47` → paste the comment below. (Skip if auto-posted via step 5.)

**Copy-paste comment:**
```markdown
**[High] `parseAmount` truncates fractional cents**

`Math.floor(value * 100)` silently drops sub-cent precision before the rounding step, so `parseAmount("19.999")` returns `1999` instead of `2000`. Any upstream price that uses banker's rounding will now disagree with this parser.

Suggested fix:
​```suggestion
  return Math.round(value * 100);
​```

<details>
<summary>Prompt for your LLM</summary>

In `src/billing/parse.ts` at line 47, `parseAmount` currently does `Math.floor(value * 100)`, which truncates sub-cent precision — e.g. `parseAmount("19.999")` returns `1999` instead of `2000`. Replace the `Math.floor` with `Math.round` so the result agrees with banker's-rounded prices upstream.

Constraints:
- Don't change `parseAmount`'s signature or return type.
- Keep all existing tests passing.
- Add a regression test covering inputs with more than two decimal places (e.g. `"19.999"` → `2000`, `"0.005"` → `1`).
- Check `src/billing/refund.ts` for the same `Math.floor(value * 100)` pattern and fix it there too if present.

</details>
```

**Why this matters (reviewer notes, not for posting):**
- Same pattern repeats in `refund.ts:88` — worth a follow-up sweep.
- No test covers values with >2 decimal places; consider adding one alongside the fix.
````
