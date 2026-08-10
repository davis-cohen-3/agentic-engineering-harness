#!/usr/bin/env bash
# PreToolUse(Bash) guardrail: block catastrophic, hard-to-reverse shell commands.
# Contract: exit 0 = allow, exit 2 = BLOCK and feed stderr back to Claude.
# Dependency: jq. Falls OPEN if jq is missing (never block work over a missing tool).
#
# This must be a HOOK, not a permission rule: a Warren run spawns
# `claude --dangerously-skip-permissions`, which kills settings.json permissions
# but NOT hooks. This is the layer that survives an autonomous run.
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0   # fail OPEN

cmd="$(jq -r '.tool_input.command // empty')"
[ -z "$cmd" ] && exit 0

deny() {
  echo "BLOCKED (dangerous command): $1" >&2
  echo "If you truly intend this, the human must run it by hand — an autonomous run won't." >&2
  exit 2
}

# High-confidence, catastrophic, hard-to-reverse patterns only (avoid false positives).
case "$cmd" in
  # Root itself: "rm -rf /" at end of command, or "rm -rf / <flags>". NOT "rm -rf /tmp/...".
  *"rm -rf /"|*"rm -fr /"|*"rm -rf / "*|*"rm -fr / "*) deny "recursive force-delete of filesystem root" ;;
  *"rm -rf /*"*|*"rm -fr /*"*)                         deny "recursive force-delete of root glob (/*)" ;;
  *"rm -rf ~"*|*"rm -fr ~"*|*'rm -rf $HOME'*|*'rm -fr $HOME'*) deny "recursive force-delete of home" ;;
  # Catastrophic system dirs only — deliberately NOT /tmp, /var, /Users, /home (legit dev deletes).
  *"rm -rf /etc"*|*"rm -rf /usr"*|*"rm -rf /bin"*|*"rm -rf /boot"*|*"rm -rf /sys"*|*"rm -rf /System"*) \
                                                       deny "recursive force-delete of a system directory" ;;
  *"sudo rm "*)                                       deny "sudo rm" ;;
  *"mkfs"*|*"dd if="*"of=/dev/"*)                     deny "disk format / raw device write" ;;
  *"chmod -R 777"*|*"chmod 777 /"*)                   deny "world-writable permissions" ;;
  *"git reset --hard origin"*)                        deny "git reset --hard against origin (discards work)" ;;
  *"git push"*"--force"*"main"*|*"git push"*"--force"*"master"*|*"git push -f"*"main"*|*"git push -f"*"master"*) \
                                                       deny "force-push to a default branch" ;;
  *"DROP TABLE"*|*"DROP DATABASE"*|*"TRUNCATE TABLE"*) deny "destructive SQL (DROP/TRUNCATE)" ;;
  *"curl "*"| sh"*|*"curl "*"| bash"*|*"wget "*"| sh"*|*"wget "*"| bash"*) \
                                                       deny "pipe-to-shell of a remote script" ;;
  *":(){ :|:& };:"*)                                  deny "fork bomb" ;;
esac

exit 0
