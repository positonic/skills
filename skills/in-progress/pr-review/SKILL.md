---
name: pr-review
description: Adversarial, staff-engineer-level pull request review focused on production risk — correctness, security, performance, architecture, missing tests, operational risks. High signal, low noise — only reports issues a senior engineer would be grateful to catch, not style or bikeshedding. Use when user wants a deep PR review, says "review this PR", "find bugs in this PR", "staff-level review", or wants an adversarial code review of a branch, diff, or GitHub PR.
---

# PR Review

Adversarial production-risk review of a pull request. Complements [`review`](../review/SKILL.md), which checks the diff against documented standards and the originating spec. This skill instead reads the diff like a hostile staff engineer looking for bugs, regressions, and failure modes.

## Process

### 1. Pin the diff

Figure out what to review. In priority order:

1. The user passed a GitHub PR number or URL → `gh pr diff <num>` and `gh pr view <num> --json title,body,commits,files`.
2. The user passed a fixed point (branch, SHA, tag, `main`, `HEAD~5`) → `git diff <fixed-point>...HEAD` (three-dot, against merge-base).
3. The user said nothing → ask once: "Review which PR — a number, a branch, or the current branch against `main`?" Don't proceed until pinned.

Also capture the commit list: `git log <fixed-point>..HEAD --oneline` or from `gh pr view`.

### 2. Read enough to be dangerous

Before reviewing, read each touched file in full where needed — diffs lie about context. Pay particular attention to:

- Call sites of any modified function.
- The shape of data structures the diff manipulates.
- Tests that exist (or conspicuously don't) for the changed code.

While reading, **record the exact line numbers** in the post-change file for anything you might flag. GitHub PR review comments must point at a line that is part of the PR's diff (an added line, or an unchanged line adjacent to the diff). Capture the line numbers from the `+++ b/<file>` side of the diff, not the `---` side. For multi-line issues, record the start and end line.

If the PR is large (>~500 lines of diff), consider spawning parallel sub-agents — one per focus area below — and aggregating. Otherwise a single pass is fine.

### 3. Apply the reviewer prompt

The full prompt is in the next section. Follow it strictly: high signal, low noise, severity-tagged findings, concrete fixes.

### 4. Report

Output the findings exactly in the format specified below. End with a one-line summary: total findings per severity, and the single worst issue (if any).

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
3. **Architecture & design** — violations of existing patterns, tight coupling, hidden side effects, poor separation of concerns, premature abstraction, misleading naming, leaky abstractions, unclear ownership.
4. **Performance** — N+1 queries, unbounded memory growth, excessive rerenders, blocking operations, duplicate work, missing indexes, large payloads, algorithmic inefficiency.
5. **Maintainability** — unnecessarily complex logic, hard-to-test code, dead code, magic constants, poor error messages, missing observability/metrics/logging, brittle tests.
6. **Testing** — missing edge-case coverage, weak assertions, happy-path-only tests, missing integration coverage, snapshot abuse, flaky patterns.

### Output format

For each issue, output exactly this block. The location line and the fenced comment block are mandatory — they are what the user copy-pastes into GitHub.

````
## [Severity] Short title

**Location:** `path/to/file.ext:LINE` (or `path/to/file.ext:START-END` for a range)
**GitHub:** Open the PR → **Files changed** tab → navigate to `path/to/file.ext` → click the `+` on line `LINE` → paste the comment below.

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
- The line must be inside the diff hunk or on an unchanged line directly adjacent to it — otherwise GitHub will reject the comment. If the real issue is far outside the diff, say so explicitly in the reviewer notes and pick the nearest in-diff anchor line.
- If an issue is about something **missing** (e.g. a missing null check, missing test), anchor the comment to the line where the missing code should go.

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
**GitHub:** Open the PR → **Files changed** tab → navigate to `src/billing/parse.ts` → click the `+` on line `47` → paste the comment below.

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
