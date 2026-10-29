# UserPromptSubmit: when James answers a plain yes to "Record these as your
# decisions in Exponential?", allow `exponential decisions confirm` in this
# session for 15 minutes (see exponential-identity-guard.sh).
set -uo pipefail
input=$(cat)
session=$(jq -r '.session_id // empty' <<<"$input")
prompt=$(jq -r '.prompt // empty' <<<"$input")
transcript=$(jq -r '.transcript_path // empty' <<<"$input")
[[ -n "$session" && -n "$prompt" && -f "$transcript" ]] || exit 0
reply=$(tr '[:upper:]' '[:lower:]' <<<"$prompt" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
# A yes is any reply that OPENS with a yes-word and carries no hedge or
# amendment. "yes record these decisions" passes; "yes but change D-0028"
# and "yes except the last two" do not -- those are changes to apply first,
# after which the question is asked again.
[[ "$reply" =~ ^(y|yes|yep|yeah|yup|sure|ok|okay|confirmed|record them|go ahead|do it)([[:space:][:punct:]]|$) ]] || exit 0
[[ "$reply" =~ (^|[[:space:][:punct:]])(but|except|change|changes|not|don\'?t|dont|remove|drop|without|only|unless|hold|wait|instead)([[:space:][:punct:]]|$) ]] && exit 0
last=$(python3 -c '
import json,sys
t=""
for l in open(sys.argv[1]):
    try: e=json.loads(l)
    except ValueError: continue
    if e.get("type")=="assistant":
        p=[c.get("text","") for c in (e.get("message") or {}).get("content") or [] if isinstance(c,dict) and c.get("type")=="text"]
        if p: t="\n".join(p)
print(t)' "$transcript")
grep -q "Record these as your decisions in Exponential?" <<<"$last" || exit 0
mkdir -p "$HOME/.claude/state"
printf '%s %s\n' "$session" "$(date +%s)" > "$HOME/.claude/state/exponential-decision-consent"
