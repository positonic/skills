---
name: setup-merge-hook
description: Scaffold the GitHub Action that reacts to a PR merging into the **deploy trigger** — either promoting Exponential **Tickets** from `QA` to `DONE`, ticking the merged scope's **feature requirements** as met, or both. Sets the `EXPONENTIAL_TOKEN` repo secret, captures the API URL and product/workspace, and writes the workflow(s). Use once per repo, after `/setup-git-flow` has identified the deploy trigger.
---

# Setup Merge Hook

Wire up the GitHub Action that closes the loop on merge. When a feature PR (or a **Rollup PR** that promotes work through the chain) merges into the **deploy trigger** branch, the Action resolves the merged PR back to its Exponential Ticket(s) and then does one or both of:

- **promote** — transition each Ticket `QA` → `DONE`.
- **requirements** — tick every requirement pinned to that Ticket's scope as **met**, without touching Ticket status.

PR-URL is the primary linkage and commit trailers are decoration — see [ADR-0003](../../../.agents/adr/0003-pr-url-primary-trailer-fallback.md).

## Choosing the mode

Ask the user which they want. They are independent:

| Mode | Writes | Use when |
| --- | --- | --- |
| `promote` | `.github/workflows/exponential-promote.yml` | The repo treats "merged to trunk" as done. |
| `requirements` | `.github/workflows/exponential-requirements.yml` | The repo deliberately parks shipped Tickets in `QA` for a human QA pass, but still wants requirement coverage to track reality. |
| `both` | Both files | Merge means done *and* the feature has scoped requirements. |

They're separate files on purpose: each is self-contained, back-compatible with repos already running `exponential-promote.yml`, and turning one off is `rm`.

`requirements` mode only does anything for Tickets that carry both a `featureId` and a `scopeId` — Tickets outside a feature are skipped silently.

## Prerequisites

- `gh auth status` succeeds.
- `docs/agents/git-flow.md` exists. If not, error out with: *"Run `/setup-git-flow` first — this skill needs to know the deploy trigger."*
- Working inside a GitHub-hosted repo (the file format is GitHub Actions, not GitLab CI).

## Process

### 1. Read the deploy trigger

Parse `docs/agents/git-flow.md` front-matter for `deployTrigger`. If missing, fail with the same error as above.

### 2. Ensure the `EXPONENTIAL_TOKEN` secret exists

```bash
gh secret list --json name --jq '.[].name' | grep -q '^EXPONENTIAL_TOKEN$'
```

If absent, confirm with the user before writing it — this is their personal Exponential JWT going into a repo secret — then:

```bash
gh secret set EXPONENTIAL_TOKEN < <(exponential auth show --token)
```

Long-term, a scoped service-account token is preferable over a personal JWT — note that to the user.

### 3. Capture the API URL, product, and workspace

The workflow needs three non-secret values, baked into the workflow's `env:` block:

- `EXPO_API_URL` — from `exponential auth status`, or prompt. Validate it starts with `http://` or `https://`. Don't assume a default.
- `EXPO_PRODUCT` — the product slug or CUID this repo's Tickets live under.
- `EXPO_WORKSPACE` — the workspace slug (required whenever `EXPO_PRODUCT` is a slug rather than a CUID).

Confirm all three with the user; a wrong product means the hook silently matches nothing.

### 4. Scaffold the workflow file(s)

Write the template(s) for the chosen mode, substituting `<deployTrigger>`, `<EXPO_URL>`, `<EXPO_PRODUCT>`, `<EXPO_WORKSPACE>`.

Don't overwrite if a file already exists — show a diff against the new template and ask the user before clobbering.

#### Shared resolve step

Both workflows start with the same **Resolve merged PR → Tickets** step. It writes `/tmp/tickets.json`: the array of Ticket objects whose `prUrl` matches the merged PR or any child PR referenced from a Rollup PR's commit log.

> **Why the client-side `jq` filter and not `tickets list --pr`?**
> The CLI advertises `--pr` / `--branch` as workspace-wide exact-match lookups. As of exponential-cli **1.0.0 they are accepted and ignored** — the filtered and unfiltered calls return the identical full ticket list, and `--pr` additionally errors out without `--product` despite its help text saying otherwise. Filtering `.tickets[]` on `.prUrl` locally is correct today and stays correct if the flags are ever fixed. Revisit when the CLI is fixed.

````yaml
      - name: Resolve merged PR -> Tickets
        env:
          PR_URL: ${{ github.event.pull_request.html_url }}
          BASE_SHA: ${{ github.event.pull_request.base.sha }}
          HEAD_SHA: ${{ github.event.pull_request.head.sha }}
          REPO_URL: ${{ github.event.pull_request.base.repo.html_url }}
        run: |
          set -euo pipefail
          # This PR, plus any child feature PRs referenced from a Rollup PR's
          # commit log (a Rollup PR promotes already-merged work along the chain,
          # so its own URL is on no Ticket -- its children's URLs are).
          {
            echo "$PR_URL"
            git log "$BASE_SHA..$HEAD_SHA" --format=%B \
              | grep -oE '#[0-9]+' | tr -d '#' | sort -u \
              | sed "s@^@${REPO_URL}/pull/@"
          } | sort -u > /tmp/prs
          jq -R -s -c 'split("\n") | map(select(length > 0))' /tmp/prs > /tmp/prs.json
          exponential tickets list \
            --product "$EXPO_PRODUCT" --workspace "$EXPO_WORKSPACE" --json > /tmp/all.json
          jq --slurpfile prs /tmp/prs.json \
            '[.tickets[] | select(.prUrl != null and (.prUrl as $u | $prs[0] | index($u)))]' \
            /tmp/all.json > /tmp/tickets.json
          echo "Matched $(jq length /tmp/tickets.json) ticket(s)."
````

#### `exponential-requirements.yml`

````yaml
# Marks a merged scope's Exponential feature requirements as met.
#
# Semantics: a requirement says "the system shall...". This hook ticks a scope's
# requirements because that scope's PR merged into <deployTrigger> green -- i.e.
# verified-shipped, not merely written. That is the intended meaning of "met".
#
# ASSUMPTION: ticket = one scope = one PR. If a scope ever spans multiple PRs,
# the FIRST of them to merge ticks the whole scope and over-claims. There is no
# signal in the merge event to detect that -- if you start splitting scopes
# across PRs, either split the scope in Exponential too, or drop this hook for
# that feature and tick by hand.
#
# This workflow never changes Ticket status. Promotion is a separate concern
# (see exponential-promote.yml) and is deliberately not wired up here.
name: Tick Exponential Requirements
on:
  pull_request:
    types: [closed]
    branches: [<deployTrigger>]
env:
  EXPO_API_URL: <EXPO_URL>
  EXPO_PRODUCT: <EXPO_PRODUCT>
  EXPO_WORKSPACE: <EXPO_WORKSPACE>
jobs:
  tick-requirements:
    if: github.event.pull_request.merged == true
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm i -g exponential-cli
      - name: Auth
        env:
          EXPO_TOKEN: ${{ secrets.EXPONENTIAL_TOKEN }}
        run: exponential auth login --token "$EXPO_TOKEN" --api-url "$EXPO_API_URL"

      # <-- insert the shared "Resolve merged PR -> Tickets" step here -->

      - name: Tick requirements for each merged scope
        run: |
          set -euo pipefail
          jq -r '.[]
                 | select(.featureId != null and .scopeId != null)
                 | [.id, .shortId, .featureId, .scopeId] | @tsv' /tmp/tickets.json \
          | while IFS=$'\t' read -r tid shortid fid sid; do
              echo "::group::$shortid ($tid) scope $sid"
              # Already-met requirements are skipped, so re-runs are idempotent.
              exponential features requirements list --feature "$fid" --scope "$sid" \
                | jq -r '.requirements[] | select(.checkedAt == null) | .id' \
                | while read -r rid; do
                    echo "check $rid"
                    exponential features requirements check --id "$rid"
                  done
              echo "::endgroup::"
            done
````

#### `exponential-promote.yml`

Identical scaffolding (name it `Promote Exponential Tickets`, job `promote`), with the final step:

````yaml
      - name: Promote
        env:
          PR_URL: ${{ github.event.pull_request.html_url }}
        run: |
          set -euo pipefail
          jq -r '.[].id' /tmp/tickets.json | while read -r cuid; do
            exponential tickets update --id "$cuid" --status DONE
            exponential tickets comment add --id "$cuid" -m "Shipped: $PR_URL"
          done
````

### 5. Dry-run the requirements path before handing over

If `requirements` mode is in play, prove the CLI chain works without waiting for a real merge. Pick one scope with a small requirement count, then tick and immediately untick so the live count stays honest:

```bash
exponential features requirements list --feature <featureId> --scope <scopeId>
exponential features requirements check --id <requirementId>
# confirm the feature's met-count moved in the UI, then undo:
exponential features requirements check --id <requirementId> --unmet
```

Never leave a test tick in place — a met requirement is a claim that the system does the thing.

### 6. Do not commit

After writing, print:

> Workflow(s) written. Review, then commit + push to activate:
>
> ```bash
> git add .github/workflows/
> git commit -m "ci: add Exponential merge hook"
> git push
> ```

This is intentional: a CI workflow is shared infrastructure, and the user should eyeball it before pushing.

## Failure modes

- **No `gh` auth** — bail with `gh auth login` instructions.
- **No `docs/agents/git-flow.md`** — bail; recommend `/setup-git-flow`.
- **Workflow file already exists** — diff against the new template, ask before overwriting.
- **API URL / product / workspace not in config** — prompt explicitly; don't guess. A wrong product matches zero Tickets and the hook fails silently green.
- **Ticket has no `featureId`/`scopeId`** — skipped by `requirements` mode; that's expected for standalone Tickets, not an error.

## What this skill does NOT do

- Run the workflow. The user commits + pushes to activate.
- Promote Tickets in `requirements` mode. That's the whole point of the split — repos that keep a human QA gate get requirement tracking without losing it.
- Set up rotating service-account tokens. Personal JWT is the current state; rotate later.
- Handle GitLab CI / Bitbucket pipelines. GitHub Actions only.
