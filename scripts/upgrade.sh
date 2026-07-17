#!/usr/bin/env bash
set -euo pipefail

# Upgrade a Mode-B (symlink) install of this fork's skills:
#   1. fast-forward the checkout,
#   2. re-link every skill into the harness skill dirs,
#   3. prune symlinks left dangling by renamed or deleted skills.
#
# Plugin installs (`claude plugin install syntro-skills@syntrofi`) don't need
# this — they update automatically when the plugin version is bumped.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DESTS=("$HOME/.claude/skills" "$HOME/.agents/skills")

echo "==> Pulling latest main"
git -C "$REPO" pull --ff-only

echo "==> Re-linking skills"
bash "$REPO/scripts/link-skills.sh"

echo "==> Pruning dangling symlinks"
for DEST in "${DESTS[@]}"; do
  [ -d "$DEST" ] || continue
  for link in "$DEST"/*; do
    if [ -L "$link" ] && [ ! -e "$link" ]; then
      rm "$link"
      echo "pruned $(basename "$link") ($DEST)"
    fi
  done
done

echo "==> Done. New/changed skills take effect in your next agent session."
