# Hooks for the consent step

Copy both scripts to `~/.claude/hooks/` and register them in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [ { "type": "command", "command": "bash ~/.claude/hooks/exponential-identity-guard.sh" } ] }
    ],
    "UserPromptSubmit": [
      { "hooks": [ { "type": "command", "command": "bash ~/.claude/hooks/exponential-decision-consent.sh" } ] }
    ]
  }
}
```

The guard is dormant until the agent's service-account token exists at `~/.config/agent-homes/claude/Library/Preferences/exponential-cli-nodejs/config.json`. Consent lasts 15 minutes and is scoped to the session that typed the yes.
