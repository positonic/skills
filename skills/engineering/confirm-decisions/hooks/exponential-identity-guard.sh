#!/usr/bin/env bash
# PreToolUse/Bash guard: keep agents off James's personal Exponential token.
#
# The exponential CLI reads its token from $HOME/Library/Preferences/
# exponential-cli-nodejs/config.json and has no --token or env-var override,
# so the ONLY way to authenticate as a different principal is to point HOME
# at a different directory for the duration of the call. Forgetting the
# prefix does not fail — it silently writes as James. This hook makes it
# fail loudly instead.
#
# Dormant until the service-account token is actually installed, so it never
# blocks work before setup is finished.
set -uo pipefail

AGENT_HOME="$HOME/.config/agent-homes/claude"
TOKEN_FILE="$AGENT_HOME/Library/Preferences/exponential-cli-nodejs/config.json"

# No service-account token installed yet -> nothing to enforce.
[[ -f "$TOKEN_FILE" ]] || exit 0

input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null) || exit 0
[[ -z "$cmd" ]] && exit 0

# Blank out invocations that already carry the right prefix, in any of the
# spellings a caller might reasonably write.
stripped=$(AGENT_HOME="$AGENT_HOME" perl -pe 's{HOME=(?:\Q$ENV{AGENT_HOME}\E|~/\.config/agent-homes/claude|\$HOME/\.config/agent-homes/claude)\s+exponential\b}{__PREFIXED__}g' <<<"$cmd")

# Grilling closing step: after James's yes (exponential-decision-consent.sh),
# `exponential decisions confirm` -- and only that -- passes for 15 minutes.
CONSENT="$HOME/.claude/state/exponential-decision-consent"
if [[ -f "$CONSENT" ]]; then
  session=$(jq -r '.session_id // empty' <<<"$input" 2>/dev/null)
  read -r consent_session consent_at < "$CONSENT"
  if [[ -n "$session" && "$session" == "$consent_session" ]] && (( $(date +%s) - consent_at < 900 )); then
    stripped=$(perl -pe 's{(^|[;&|(]|\$\(|&&|\|\|)(\s*)exponential\s+decisions\s+confirm\b}{$1$2__CONSENTED__}g' <<<"$stripped")
  fi
fi

# Anything left calling `exponential` in command position is unprefixed.
# NB: a bare backtick is deliberately NOT a command-position marker. Legacy
# `cmd` substitution is vanishingly rare next to markdown inline code, and
# treating it as one blocks any command whose payload merely *mentions*
# `exponential ...` — e.g. writing a ticket comment about this very guard.
if grep -qE '(^|[;&|(]|\$\(|&&|\|\|)[[:space:]]*exponential([[:space:]]|$)' <<<"$stripped"; then
  cat <<JSON
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Unprefixed \`exponential\` call. Without the HOME= prefix this authenticates as James's personal account, not the claude service account, and any ticket/comment it writes is misattributed. Re-run as: HOME=$AGENT_HOME exponential ..."}}
JSON
  exit 0
fi

exit 0
