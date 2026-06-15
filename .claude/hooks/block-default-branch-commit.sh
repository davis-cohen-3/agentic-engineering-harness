#!/usr/bin/env bash
# PreToolUse(Bash) guardrail: block git commit/push while on the default branch.
# Contract: exit 0 = allow, exit 2 = BLOCK and feed stderr back to Claude.
# Dependency: jq (parses the hook's JSON stdin). Falls open if jq is missing.
set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0   # fail OPEN: never block work over a missing tool

cmd="$(jq -r '.tool_input.command // empty')"

# Only inspect git commit / git push — let everything else through fast.
case "$cmd" in
  *"git commit"*|*"git push"*) ;;
  *) exit 0 ;;
esac

branch="$(git branch --show-current 2>/dev/null || echo '')"
default="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@' || true)"
default="${default:-main}"

if [ "$branch" = "$default" ] || [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
  echo "Blocked: you are on '$branch' (the default branch). Create a task branch first (git switch -c <name>), then commit." >&2
  exit 2
fi
exit 0
