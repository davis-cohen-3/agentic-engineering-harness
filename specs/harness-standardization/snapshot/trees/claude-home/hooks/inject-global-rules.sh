#!/usr/bin/env bash
# SessionStart hook (GLOBAL ~/.claude): inject the global rules ONLY when this session is NOT
# inside a project that owns its own .claude/ or CLAUDE.md. Walking up from cwd, the first
# ancestor (other than $HOME) carrying a project marker means "a project governs this session"
# → stay silent, so the project's own CLAUDE.md/FLOOR/rules win and the global rules cost zero
# tokens here. Outside any such project (scratch dirs, $HOME, un-adopted repos) → inject them.
# Fails OPEN: any error → no injection, never blocks the session.
set -euo pipefail

RULES_DIR="$HOME/.claude/rules"
[ -d "$RULES_DIR" ] || exit 0   # nothing to inject

# Resolve cwd from the hook payload (stdin JSON), falling back to PWD.
payload="$(cat 2>/dev/null || true)"
cwd=""
if command -v jq >/dev/null 2>&1 && [ -n "$payload" ]; then
  cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)"
fi
[ -z "$cwd" ] && cwd="$PWD"

# Walk up from cwd; a project marker in any ancestor EXCEPT $HOME ⇒ a project owns this session.
d="$cwd"
while [ -n "$d" ] && [ "$d" != "/" ]; do
  if [ "$d" != "$HOME" ] && { [ -d "$d/.claude" ] || [ -f "$d/CLAUDE.md" ]; }; then
    exit 0   # project-owned session → suppress global rules
  fi
  d="$(dirname "$d")"
done

# Not in a project → concatenate every global rule file and inject as session context.
body=""
for f in "$RULES_DIR"/*.md; do
  [ -f "$f" ] || continue
  case "$(basename "$f")" in README.md|readme.md) continue ;; esac   # docs, not a rule
  body="$body"$'\n\n'"$(cat "$f")"
done
body="$(printf '%s' "$body" | sed -e '/[^[:space:]]/,$!d')"   # strip leading blank lines
[ -z "$body" ] && exit 0

ctx="Global preferences & rules (~/.claude/rules/) — active because this session is NOT inside a project with its own .claude/. Inside such a project these are fully suppressed and the project's own CLAUDE.md/FLOOR/rules govern instead.${body}"

if command -v jq >/dev/null 2>&1; then
  jq -cn --arg ctx "$ctx" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}'
else
  printf '%s\n' "$ctx"   # fail OPEN: plain stdout is still added to context on SessionStart
fi
exit 0
