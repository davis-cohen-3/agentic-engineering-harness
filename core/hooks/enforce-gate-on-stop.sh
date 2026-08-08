#!/usr/bin/env bash
# Stop hook: make the quality gate the REAL stop condition.
#
# Why this exists: Warren decides a run succeeded from the agent's own is_error
# envelope, NOT from `make check`. Without this, an agent can claim "done" on a
# RED gate and Warren will push the branch. This hook fails the turn until the
# gate is green — and it travels into the burrow sandbox via the repo clone,
# where Warren cannot override it.
#
# Contract: exit 0 = allow stop (done). exit 2 = block stop; stderr -> the agent
# keeps working. Circuit breaker: after MAX_RETRIES red gates, allow stop and
# surface loudly, so an AUTONOMOUS run never loops forever (the "5-10 failures"
# rule). In Warren, pair the give-up case with a host-side reap gate for true
# belt-and-suspenders (see project-warren-integration).
set -uo pipefail

MAX_RETRIES=5
input="$(cat)"

if command -v jq >/dev/null 2>&1; then
  session="$(printf '%s' "$input" | jq -r '.session_id // "nosession"')"
else
  session="nosession"   # jq missing -> fail open below
fi

# No gate defined? nothing to enforce.
{ [ -f Makefile ] && grep -q '^check:' Makefile; } || exit 0

state="${TMPDIR:-/tmp}/harness-gate-${session}"
out="${TMPDIR:-/tmp}/harness-gate-out-${session}"

if make check >"$out" 2>&1; then
  rm -f "$state"
  exit 0   # gate GREEN -> truly done, allow stop
fi

# Gate RED -> count attempts.
count=$(( $(cat "$state" 2>/dev/null || echo 0) + 1 ))
echo "$count" > "$state"

if [ "$count" -gt "$MAX_RETRIES" ]; then
  rm -f "$state"
  echo "CIRCUIT BREAKER: quality gate still RED after ${MAX_RETRIES} attempts. Allowing stop and surfacing for human review. Do NOT claim success — report the failure plainly." >&2
  exit 0
fi

{
  echo "Quality gate FAILED (attempt ${count}/${MAX_RETRIES}). You are NOT done."
  echo "Fix the failures below; \`make check\` must exit 0 before you finish."
  echo "----- make check output (tail) -----"
  tail -n 40 "$out"
} >&2
exit 2
