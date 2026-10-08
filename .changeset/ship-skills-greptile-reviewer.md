---
"syntro-skills": minor
---

Teach the ship skills to use **Greptile** as the automated reviewer, and stop them waiting on a **disabled PR-Agent workflow**.

**Greptile is now the first reviewer `ship-this` probes for**, ahead of PR-Agent, CodeRabbit and a local `/pr-review`. It's a GitHub App with no file in the repo, so detection is by its `Greptile Review` check run on recent PRs' head commits. It wins over PR-Agent because a repo with both has almost always installed Greptile to replace an older PR-Agent workflow.

The new Greptile path (7b) gates on the **`Greptile Review` check run for the current head SHA completing**, and reads only the inline comments whose `commit_id` is that SHA — older ones describe code that has since changed. The `<!-- greptile_summary -->` comment is edited in place, so as with PR-Agent, "a new comment appeared" is never the signal. P0/P1 findings come first; P2 is advisory.

**Greptile doesn't review every push** — it reviews the tip of a multi-commit push, and skips some pushes outright (three of the last eight PRs on one repo had no review on their final commit). So the wait has a third outcome besides done and timed-out: no run started within 5 minutes. In round 1 that falls back to `/pr-review`; in round 2 it ends the loop.

**PR-Agent detection now requires the workflow to be `active`.** Disabling a workflow in the Actions UI leaves the file in `.github/workflows/`, so the old file-only probe picked PR-Agent and burned the full 15-minute timeout on every ship before falling back. `.pr_agent.toml` alone no longer counts either — it configures the action, it doesn't run anything.

`ship-ticket` delegates to `ship-this` step 7, so only its one-line summary of the probe order changed.
