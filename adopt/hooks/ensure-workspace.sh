#!/usr/bin/env bash
# ensure-workspace.sh — make .workspace/ exist. Idempotent, read-mostly, fails open.
#
# Runs as SessionStart (the net for Codex, plain `git worktree add`, a provider setting that
# did not take) and eagerly from `wt` and Claude's WorktreeCreate. Whoever gets there first wins;
# the others are no-ops.
#
# It must be a SEPARATE script from inject-global-rules.sh, whose core logic exits early whenever
# an ancestor has .claude/ or CLAUDE.md — i.e. in every adopted repo, exactly where init is needed.
#
# NEVER overwrites an existing MISSION.md. It is the one file in .workspace/ that may be
# overwritten, but only by an agent deliberately updating it — never by initialisation.
#
# Fails open throughout: a broken workspace initialiser must not stop a session from starting.
set -uo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$root" ] || exit 0

ws="$root/.workspace"
mission="$ws/MISSION.md"

mkdir -p "$ws" 2>/dev/null || exit 0

if [ -e "$mission" ]; then
  # Present is enough. Report what it says, repair nothing.
  state="$(awk -F': *' '/^state:/{print $2; exit}' "$mission" 2>/dev/null | tr -d '\r')"
  spec="$(awk -F': *' '/^spec:/{print $2; exit}'  "$mission" 2>/dev/null | tr -d '\r')"
  if [ -z "$state" ]; then
    echo "workspace: MISSION.md has no readable 'state' — treating it as 'scoping'. Left as-is."
  fi
  if [ -n "$spec" ] && [ "$spec" != "null" ] && [ ! -e "$root/$spec" ]; then
    echo "workspace: MISSION.md points at a spec that does not exist here: $spec"
  fi
  exit 0
fi

# Create it. O_EXCL via `set -o noclobber` so two sessions racing cannot clobber each other —
# the loser's redirect fails and it simply moves on.
(
  set -o noclobber
  cat >"$mission" <<'EOF'
---
state: scoping        # scoping | building | shipped | abandoned
spec: null            # or specs/<slug>.md
---

# Mission

## Objective

## Current position

## Next action

## Blockers
EOF
) 2>/dev/null || exit 0

exit 0
