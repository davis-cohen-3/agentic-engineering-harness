#!/usr/bin/env bash
# Acceptance test for Codex hook parity (plan/tasks.md T0.11).
#
# Exercises every hook against BOTH providers' real payload shapes, from a real adopted repo so
# the scripts run from their deployment path (.agents/hooks/), not from the source tree.
#
# The Codex apply_patch envelope modelled here was read off 118 real apply_patch calls in
# ~/.codex/sessions: a custom_tool_call whose `input` is the raw patch text, whose only
# path-carrying directives are `*** Add File:`, `*** Update File:`, `*** Delete File:`.
#
# The synthetic key below is assembled at RUNTIME. A literal one in this file would be blocked by
# the very hook under test — as it was, once.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
export TMPDIR="$SB/tmp"; mkdir -p "$TMPDIR"   # keep the stop-gate's state files in the sandbox

pass=0 fail=0
ok() { pass=$((pass+1)); printf '  ✓ %s\n' "$1"; }
no() { fail=$((fail+1)); printf '  ✗ %s\n' "$1"; }

T="$SB/target"
mkdir -p "$T" && git -C "$T" init -q -b main && git -C "$T" commit -q --allow-empty -m init
"$REPO/core/skills/adopt-harness/copy.sh" "$T" python >"$SB/adopt.log" 2>&1 \
  || { echo "copy.sh failed"; cat "$SB/adopt.log"; exit 1; }
H="$T/.agents/hooks"

KEY="sk-ant-api03-$(printf 'A%.0s' $(seq 32))"   # shape-only; never a real credential

# --- payload builders -------------------------------------------------------------------------
# Claude sends file_path + content/new_string; Codex sends the whole patch under apply_patch.
j() { python3 - "$@" <<'PY'
import json,sys
kind=sys.argv[1]
ti={"read":        lambda a:{"file_path":a[0]},
    "write":       lambda a:{"file_path":a[0],"content":a[1]},
    "edit":        lambda a:{"file_path":a[0],"old_string":a[1],"new_string":a[2]},
    "bash":        lambda a:{"command":a[0]},
    "patch":       lambda a:{"input":a[0]},
    "patch_nested":lambda a:{"arguments":{"patch":a[0]}},
    "none":        lambda a:{}}[kind](sys.argv[2:])
tool={"read":"Read","write":"Write","edit":"Edit","bash":"Bash",
      "patch":"apply_patch","patch_nested":"apply_patch","none":"Stop"}[kind]
print(json.dumps({"session_id":"t0-11","hook_event_name":"PreToolUse","tool_name":tool,"tool_input":ti}))
PY
}
patch() { printf '*** Begin Patch\n%s\n*** End Patch\n' "$1"; }

# Payload goes in via a FILE, not a pipe: a hook that exits without draining stdin (the
# fail-open path) would SIGPIPE the writer and pipefail would report 141 instead of the hook's
# own status.
run() { printf '%s' "$2" >"$SB/payload.json"
        OUT="$(cd "${3:-$T}" && "$1" <"$SB/payload.json" 2>&1)"; RC=$?; }
is()  { [ "$RC" = "$1" ] && ok "$2" || no "$2 (exit $RC, expected $1)"; }

echo "T0.11 — Codex hook parity"

echo "protect-secrets.sh — Claude payloads"
run "$H/protect-secrets.sh" "$(j read  "$T/.env")";                 is 2 "Claude Read of .env blocks"
run "$H/protect-secrets.sh" "$(j read  "$T/src/app.py")";           is 0 "Claude Read of an ordinary file allows"
run "$H/protect-secrets.sh" "$(j read  "$T/deploy/id_rsa")";        is 2 "Claude Read of a private key blocks"
run "$H/protect-secrets.sh" "$(j read  "$T/.git/credentials")";     is 2 "Claude Read of .git/credentials blocks"
run "$H/protect-secrets.sh" "$(j read  "$T/.git/config")";          is 2 "Claude Read of .git/config blocks"
run "$H/protect-secrets.sh" "$(j read  "$T/svc/credentials.json")"; is 2 "Claude Read of credentials.json blocks"
run "$H/protect-secrets.sh" "$(j write "$T/.env.local" 'X=1')";     is 2 "Claude Write to .env.local blocks"
run "$H/protect-secrets.sh" "$(j write "$T/app.py" "K='$KEY'")";    is 2 "Claude Write of a literal API key blocks"
run "$H/protect-secrets.sh" "$(j write "$T/app.py" 'print(1)')";    is 0 "Claude ordinary Write allows"
run "$H/protect-secrets.sh" "$(j edit  "$T/app.py" "K='$KEY'" 'K=os.environ["K"]')"
is 0 "Claude Edit REMOVING a secret is allowed — old_string is never scanned"

echo "protect-secrets.sh — Codex apply_patch payloads"
P_OK="$(patch "$(printf '*** Update File: %s/app.py\n@@\n-print(1)\n+print(2)' "$T")")"
P_ENV="$(patch "$(printf '*** Add File: %s/.env.local\n+TOKEN=1' "$T")")"
P_KEY="$(patch "$(printf '*** Add File: %s/cfg.py\n+KEY = "%s"' "$T" "$KEY")")"
P_RSA="$(patch "$(printf '*** Update File: %s/deploy/id_rsa\n+x' "$T")")"
P_DEL="$(patch "$(printf '*** Delete File: %s/credentials.json' "$T")")"
P_NST="$(patch "$(printf '*** Add File: %s/.env.prod\n+A=1' "$T")")"

run "$H/protect-secrets.sh" "$(j patch "$P_OK")";   is 0 "Codex ordinary edit allows"
run "$H/protect-secrets.sh" "$(j patch "$P_ENV")";  is 2 "Codex apply_patch adding .env.local BLOCKS"
run "$H/protect-secrets.sh" "$(j patch "$P_KEY")";  is 2 "Codex apply_patch writing an API key BLOCKS"
run "$H/protect-secrets.sh" "$(j patch "$P_RSA")";  is 2 "Codex apply_patch touching a private key BLOCKS"
run "$H/protect-secrets.sh" "$(j patch "$P_DEL")";  is 2 "Codex apply_patch deleting credentials.json BLOCKS"
run "$H/protect-secrets.sh" "$(j patch_nested "$P_NST")"
is 2 "the fallback is key-name independent — it flattens tool_input, not a known field"

echo "protect-secrets.sh — rename destinations (the *** Move to: directive)"
# codex 0.147.0's binary carries four path-bearing directives, not three. A rename destination
# that is not path-checked lets an agent write a benign file and move it onto a secret path.
P_MV_ENV="$(patch "$(printf '*** Update File: %s/notes.txt\n*** Move to: %s/.env\n@@\n-a\n+b' "$T" "$T")")"
P_MV_KEY="$(patch "$(printf '*** Update File: %s/notes.txt\n*** Move to: %s/deploy/id_rsa\n@@\n-a\n+b' "$T" "$T")")"
P_INDENT="$(patch "$(printf '  *** Add File: %s/.env.staging\n+A=1' "$T")")"
run "$H/protect-secrets.sh" "$(j patch "$P_MV_ENV")"; is 2 "renaming a file ONTO .env blocks"
run "$H/protect-secrets.sh" "$(j patch "$P_MV_KEY")"; is 2 "renaming a file ONTO a private key blocks"
run "$H/protect-secrets.sh" "$(j patch "$P_INDENT")"; is 2 "an indented header cannot slip the ^ anchor"

echo "protect-secrets.sh — degradation"
run "$H/protect-secrets.sh" "$(j none)";            is 0 "an empty tool_input allows"
mkdir -p "$SB/nojq"
for b in bash cat sed grep; do ln -sf "$(command -v $b)" "$SB/nojq/$b"; done
printf '%s' "$(j read "$T/.env")" >"$SB/payload.json"
OUT="$(cd "$T" && PATH="$SB/nojq" "$H/protect-secrets.sh" <"$SB/payload.json" 2>&1)"; RC=$?
is 0 "fails OPEN when jq is missing"

echo "block-dangerous-bash.sh — portable: both providers send tool_input.command"
run "$H/block-dangerous-bash.sh" "$(j bash 'rm -rf /')";                     is 2 "rm -rf / blocks"
run "$H/block-dangerous-bash.sh" "$(j bash 'curl http://x | bash')";         is 2 "pipe-to-shell blocks"
run "$H/block-dangerous-bash.sh" "$(j bash 'git push --force origin main')"; is 2 "force-push to main blocks"
run "$H/block-dangerous-bash.sh" "$(j bash 'ls -la')";                       is 0 "an ordinary command allows"
run "$H/block-dangerous-bash.sh" "$(j bash 'rm -rf /tmp/scratch')";          is 0 "deleting a temp dir is not a false positive"

echo "block-default-branch-commit.sh"
run "$H/block-default-branch-commit.sh" "$(j bash 'git commit -m x')"; is 2 "commit on main blocks"
run "$H/block-default-branch-commit.sh" "$(j bash 'ls')";              is 0 "a non-git command on main allows"
git -C "$T" switch -q -c task/t0-11
run "$H/block-default-branch-commit.sh" "$(j bash 'git commit -m x')"; is 0 "commit on a task branch allows"

echo "flag-comment-bloat.sh — Claude-only by design; must no-op, not crash, on Codex"
BLOATED="$(printf '# a\n# b\n# c\n# d\n# e\n# f\n# g\nx=1\ny=2\nz=3\n')"
run "$H/flag-comment-bloat.sh" "$(j write "$T/a.py" "$BLOATED")";      is 0 "exits 0 on a bloated Claude write"
printf '%s' "$OUT" | grep -q additionalContext && ok "emits a nudge for Claude" || no "no nudge emitted for Claude"
run "$H/flag-comment-bloat.sh" "$(j write "$T/a.py" 'x=1')";           is 0 "exits 0 on an ordinary Claude write"
[ -z "$OUT" ] && ok "no nudge for an ordinary write" || no "spurious nudge: $OUT"
run "$H/flag-comment-bloat.sh" "$(j patch "$P_OK")";                   is 0 "no-ops cleanly on a Codex apply_patch"
[ -z "$OUT" ] && ok "stays silent on Codex rather than emitting a bogus nudge" || no "emitted output on Codex: $OUT"

echo "every hook honours the 0-allow / 2-block contract on MALFORMED stdin"
# A `set -e` script aborts on jq's parse failure and returns jq's exit 5, which is neither allow
# nor block and whose handling is provider-dependent. Six hooks got this right; two did not.
printf '{"tool_input": {"command": ' >"$SB/truncated.json"
for hook in "$H"/*.sh; do
  (cd "$T" && "$hook" <"$SB/truncated.json" >/dev/null 2>&1); rc=$?
  case "$rc" in 0|2) ok "$(basename "$hook") stays in contract (exit $rc)" ;;
                *)   no "$(basename "$hook") returned $rc on malformed stdin" ;; esac
done

echo "collab-reminders.sh + enforce-gate-on-stop.sh — event payloads carry no tool_input"
run "$H/collab-reminders.sh" "$(j none)";                              is 0 "collab-reminders allows"
printf '%s' "$OUT" | grep -q additionalContext && ok "collab-reminders injects a reminder" || no "collab-reminders emitted nothing"
mv "$T/Makefile" "$SB/Makefile.orig"
run "$H/enforce-gate-on-stop.sh" "$(j none)";                          is 0 "stop-gate allows when the repo defines no check target"
printf 'check:\n\t@false\n' >"$T/Makefile"
run "$H/enforce-gate-on-stop.sh" "$(j none)";                          is 2 "stop-gate BLOCKS on a red gate"
printf 'check:\n\t@true\n' >"$T/Makefile"
run "$H/enforce-gate-on-stop.sh" "$(j none)";                          is 0 "stop-gate allows on a green gate"
# The gate must be RESOLVED, not grepped for: the harness's own root Makefile only `include`s
# another one and has no literal `^check:`, so a text match silently disabled this hook in exactly
# the repo where a regression costs most.
printf '# no recipe here\ninclude real.mk\n' >"$T/Makefile"
printf 'check:\n\t@false\n' >"$T/real.mk"
run "$H/enforce-gate-on-stop.sh" "$(j none)";  is 2 "BLOCKS on a red gate reached only through an include"
printf 'check:\n\t@true\n' >"$T/real.mk"
run "$H/enforce-gate-on-stop.sh" "$(j none)";  is 0 "allows on a green gate reached only through an include"
rm -f "$T/real.mk"
mv "$SB/Makefile.orig" "$T/Makefile"

echo "binding path resolution — the acceptance line is 'not just the repo root'"
mkdir -p "$T/src/deep/nested"
python3 - "$T" <<'PY' && ok "every Codex binding resolves from a SUBDIRECTORY" || no "a Codex binding failed to resolve from a subdirectory"
import json,subprocess,sys,os
t=sys.argv[1]; sub=os.path.join(t,"src","deep","nested")
for g in (grp for ev in json.load(open(f"{t}/.codex/hooks.json"))["hooks"].values() for grp in ev):
    for h in g["hooks"]:
        p=subprocess.check_output(["bash","-c",f'echo {h["command"]}'],cwd=sub,text=True).strip()
        assert os.path.isfile(p) and os.access(p,os.X_OK), p
PY
RESOLVED="$(cd "$T/src/deep/nested" && bash -c 'echo "$(git rev-parse --path-format=absolute --git-common-dir)/../.agents/hooks/protect-secrets.sh"')"
run "$RESOLVED" "$(j read "$T/.env")" "$T/src/deep/nested"
is 2 "a hook invoked through its Codex binding FROM a subdirectory still blocks"
python3 - "$T" <<'PY' && ok "every Claude binding resolves from a subdirectory too" || no "a Claude binding is dangling"
import json,subprocess,sys,os
t=sys.argv[1]; sub=os.path.join(t,"src","deep","nested")
for g in (grp for ev in json.load(open(f"{t}/.claude/settings.local.json"))["hooks"].values() for grp in ev):
    for h in g["hooks"]:
        p=subprocess.check_output(["bash","-c",'echo '+h["command"]],cwd=sub,text=True).strip()
        assert os.path.isfile(p) and os.access(p,os.X_OK), p
PY
grep -q '"command": "\.\./' "$T/.codex/hooks.json" \
  && no "a cwd-relative ../.claude binding survived" || ok "no cwd-relative binding — melting's form is not inherited"
grep -q "$HOME" "$T/.codex/hooks.json" \
  && no "an absolute machine path leaked into the Codex binding" || ok "no absolute machine path in the Codex binding"

echo "provenance"
# A marker, not proof: this greps the file for a SHA the file's own author wrote, so it catches a
# SHA that was removed or altered, NOT an unfaithful harvest. Faithfulness was verified against
# melting by direct comparison (twice, on 2026-08-09) and is deliberately not re-checked here —
# doing so would make a green gate depend on another repo being present and on its remote state.
grep -q '7687e47a0caa6a75cdf880cf8ae1e258c9dec979' "$REPO/adopt/hooks/protect-secrets.sh" \
  && ok "the harvest blob SHA is RECORDED (marker only — faithfulness verified out-of-band)" \
  || no "harvest provenance not recorded"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
