#!/usr/bin/env bash
# PostToolUse(Write|Edit) hook: HABIT nudge for comment bloat (collaboration
# layer, not a gate). Looks at the lines THIS edit added; if too many are
# comments, injects a nudge at the moment of the edit instead of front-loading a
# style rule the agent forgets. Nudge-only: exit 0, never blocks. Fails OPEN.
# Conservative by design (fuzzy signal): skips docs/data, ignores small edits.
# Tune via MIN_LINES (ignore small edits) + MAX_RATIO (allowed comment percent).
set -euo pipefail

MIN_LINES=10        # don't nag on small edits
MAX_RATIO=30        # percent of added non-blank lines that may be comments

command -v jq >/dev/null 2>&1 || exit 0   # can't parse input -> fail open

input="$(cat)"
file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')"

# Skip non-code: docs/data/markup are legitimately prose- or markup-heavy.
case "${file##*.}" in
  md|mdx|markdown|txt|rst|json|yaml|yml|toml|ini|cfg|lock|csv|tsv|html|xml|svg) exit 0 ;;
esac

# Text this call added: Write -> whole content; Edit -> new_string.
added="$(printf '%s' "$input" | jq -r '.tool_input.content // .tool_input.new_string // ""')"
[ -z "$added" ] && exit 0

total=0; comments=0
while IFS= read -r line; do
  trimmed="${line#"${line%%[![:space:]]*}"}"   # strip leading whitespace
  [ -z "$trimmed" ] && continue
  total=$((total + 1))
  case "$trimmed" in
    '#'*|'//'*|'/*'*|'*'*|'--'*|';'*|'"""'*|"'''"*|'<!--'*) comments=$((comments + 1)) ;;
  esac
done <<EOF
$added
EOF

[ "$total" -lt "$MIN_LINES" ] && exit 0
ratio=$(( comments * 100 / total ))
[ "$ratio" -le "$MAX_RATIO" ] && exit 0

msg="Heads up: ~${ratio}% of the lines you just wrote to ${file##*/} are comments. Prefer minimal comments — the non-obvious *why*, never the *what*. Consider trimming before you move on."
jq -cn --arg ctx "$msg" \
  '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
exit 0
