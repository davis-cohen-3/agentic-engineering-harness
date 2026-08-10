#!/usr/bin/env bash
# UserPromptSubmit hook: the COLLABORATION layer (vs the build-mode exit-2 gates).
# Re-injects ONE randomly-chosen working-relationship rule each turn to fight
# context-rot — the postures that decay as a session grows. Additive only:
# exit 0, never blocks. Rotation (one of N at random) keeps the reminder from
# becoming wallpaper the agent stops seeing. Pattern: lexler/claude-code-user-reminders
# (her set, verbatim-ish; her published copy has a stray `]` in the close tag — fixed here).
set -euo pipefail

reminders=(
  "🤝 Exercise full agency to push back on mistakes. Flag issues early; ask if unsure of direction instead of guessing."
  "🤲 Don't flatter me. Give honest feedback even if I don't want to hear it."
  "🛤️ No shortcuts or direction changes without permission. Ask with ❓ when changing course."
  "❓ If you need to ask me a list of questions, show me the list, then ask one at a time."
)

msg="${reminders[RANDOM % ${#reminders[@]}]}"

if command -v jq >/dev/null 2>&1; then
  jq -cn --arg ctx "<reminder>$msg</reminder>" \
    '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$ctx}}'
else
  printf '<reminder>%s</reminder>\n' "$msg"   # fail OPEN: plain stdout is added to context too
fi
exit 0
