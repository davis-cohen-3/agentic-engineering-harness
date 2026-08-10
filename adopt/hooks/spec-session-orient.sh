#!/usr/bin/env bash
# SessionStart hook: orient the session to where this worktree already is.
#
# STRICTLY READ-ONLY. It writes nothing — no pointer, no notepad, no repair. The previous version
# self-bound by writing .claude/active-spec and created a scratch notepad; both surfaces are
# retired, and a hook that writes is a hook that can corrupt what it is describing.
#
# It reads .workspace/MISSION.md, which ensure-workspace.sh creates. That hook MUST be registered
# BEFORE this one in SessionStart, or the first session in a fresh worktree orients against
# nothing.
#
# FILENAMES ONLY, never contents: the point is to tell the session what exists and let it choose
# what to open. Dumping a handoff into every session's context is the cost this avoids.
#
# Fails OPEN throughout, and stays silent when nothing resolves — a hook that nags on every
# trivial task gets ignored, and then it is not a signal.
set -uo pipefail

command -v git >/dev/null 2>&1 || exit 0
root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$root" ] || exit 0

ws="$root/.workspace"
mission="$ws/MISSION.md"
lines=""
add() { lines="${lines:+$lines }$1"; }

if [ -f "$mission" ]; then
  state="$(awk -F': *' '/^state:/{sub(/[[:space:]]*#.*/,"",$2); print $2; exit}' "$mission" 2>/dev/null | tr -d '\r')"
  spec="$(awk  -F': *' '/^spec:/{sub(/[[:space:]]*#.*/,"",$2);  print $2; exit}' "$mission" 2>/dev/null | tr -d '\r')"
  next="$(awk '/^## Next action/{f=1;next} /^## /{f=0} f && NF {print; exit}' "$mission" 2>/dev/null)"

  [ -n "$state" ] && add "Mission state: $state."
  if [ -n "$spec" ] && [ "$spec" != "null" ]; then
    if [ -e "$root/$spec" ]; then
      add "Spec: $spec — this is the RESOLVED plan; read it before acting, and treat any unresolved design point in it as a hard-stop to flag, not something to invent."
    else
      add "Spec: $spec — MISSION.md points at it but it does not exist here."
    fi
  fi
  [ -n "$next" ] && add "Next action: $next"
fi

if [ -d "$ws/history" ]; then
  newest="$(ls -1 "$ws/history" 2>/dev/null | grep -- '-handoff-' | LC_ALL=C sort | tail -1)"
  [ -n "$newest" ] && add "Newest handoff: .workspace/history/$newest (read it if you are resuming)."
  findings="$(ls -1 "$ws/history" 2>/dev/null | grep -- '-finding-' | LC_ALL=C sort | tr '\n' ' ')"
  [ -n "$findings" ] && add "Findings: $findings"
fi

[ -n "$lines" ] || exit 0   # nothing to say — say nothing

branch="$(git -C "$root" branch --show-current 2>/dev/null)"
dirty="$(git -C "$root" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
add "On branch ${branch:-(detached)} with ${dirty} uncommitted change(s)."

if command -v jq >/dev/null 2>&1; then
  jq -cn --arg ctx "$lines" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}'
else
  printf '%s\n' "$lines"
fi
exit 0
