#!/usr/bin/env bash
# Acceptance test for adopt-harness/copy.sh (plan/tasks.md T0.5).
#
# Adopts a real, disposable git repo in a temp dir and checks the three acceptance lines:
# discoverable by BOTH providers, no retired surface travels, re-running does not clobber.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT

pass=0 fail=0
ok() { pass=$((pass+1)); printf '  ✓ %s\n' "$1"; }
no() { fail=$((fail+1)); printf '  ✗ %s\n' "$1"; }
has()    { [ -e "$T/$1" ] && ok "$2"        || no "$2 (missing $1)"; }
hasnt()  { [ -e "$T/$1" ] && no "$2 ($1 travelled)" || ok "$2"; }

T="$SB/target"
mkdir -p "$T" && git -C "$T" init -q && git -C "$T" commit -q --allow-empty -m init

echo "T0.5 — adopt-harness/copy.sh"

echo "adopts a disposable repo"
if "$REPO/core/skills/adopt-harness/copy.sh" "$T" python >"$SB/out" 2>&1; then
  ok "copy.sh exits 0"
else
  no "copy.sh failed"; cat "$SB/out"
fi

echo "discoverable by Claude"
has "CLAUDE.md"                  "CLAUDE.md written"
has ".claude/settings.json"      ".claude/settings.json written"
has ".claude/hooks/protect-secrets.sh" "hook scripts landed at .claude/hooks/"
[ -x "$T/.claude/hooks/protect-secrets.sh" ] && ok "hooks are executable" || no "hooks not executable"
python3 - "$T" <<'PY' && ok "every Claude hook binding resolves to a real file" || no "a Claude hook binding is dangling"
import json,sys,os
t=sys.argv[1]; d=json.load(open(f"{t}/.claude/settings.json"))
for ev in d["hooks"].values():
    for g in ev:
        for h in g["hooks"]:
            p=h["command"].replace("$CLAUDE_PROJECT_DIR",t)
            assert os.path.isfile(p), p
PY

echo "discoverable by Codex"
has "AGENTS.md"           "AGENTS.md written (the file Codex reads)"
has ".codex/hooks.json"   ".codex/hooks.json written"
[ -L "$T/.agents/skills" ] && ok ".agents/skills is a symlink" || no ".agents/skills is not a symlink"
[ -d "$T/.agents/skills" ] && ok ".agents/skills resolves to a directory" || no ".agents/skills dangles"
[ "$(cd "$T/.agents/skills" && pwd -P)" = "$(cd "$T/.claude/skills" && pwd -P)" ] \
  && ok ".agents/skills and .claude/skills are the same directory" || no "symlink points elsewhere"
grep -q 'git rev-parse --show-toplevel' "$T/.codex/hooks.json" \
  && ok "Codex bindings resolve from the repo root, not cwd or an absolute path" || no "Codex bindings not repo-root-resolved"
# Per-matcher, not a whole-file grep: the comment-bloat group also contains the word apply_patch,
# so a file-wide match stays green while protect-secrets' own matcher loses it — which is exactly
# the CONTRACT §5 failure mode (the guard never runs on a Codex edit, and nothing says so).
python3 - "$T" <<'PY' && ok "protect-secrets' OWN matcher includes apply_patch" || no "protect-secrets would not fire on a Codex edit"
import json,sys
d=json.load(open(f"{sys.argv[1]}/.codex/hooks.json"))
for ev,groups in d["hooks"].items():
    for g in groups:
        for h in g["hooks"]:
            if "protect-secrets" in h["command"]:
                assert "apply_patch" in g.get("matcher",""), g.get("matcher")
                sys.exit(0)
sys.exit(1)
PY
python3 - "$T" <<'PY' && ok "every Codex hook binding resolves to a real file" || no "a Codex hook binding is dangling"
import json,sys,os,subprocess
t=sys.argv[1]; d=json.load(open(f"{t}/.codex/hooks.json"))
root=subprocess.check_output(["git","-C",t,"rev-parse","--show-toplevel"],text=True).strip()
for ev in d["hooks"].values():
    for g in ev:
        for h in g["hooks"]:
            p=h["command"].replace('"$(git rev-parse --show-toplevel)"',root).strip('"')
            assert os.path.isfile(p), p
PY

echo "SessionStart ordering is load-bearing"
python3 - "$T" <<'PY' && ok "ensure-workspace precedes orientation in BOTH providers" || no "orientation would run before the initialiser"
import json,sys
t=sys.argv[1]
for f in (f"{t}/.claude/settings.json", f"{t}/.codex/hooks.json"):
    cmds=[h["command"] for g in json.load(open(f))["hooks"]["SessionStart"] for h in g["hooks"]]
    i=[n for n,c in enumerate(cmds) if "ensure-workspace" in c]
    j=[n for n,c in enumerate(cmds) if "spec-session-orient" in c]
    assert i and j and i[0] < j[0], f
PY

echo "the profile is single-sourced"
grep -q '@AGENTS.md' "$T/CLAUDE.md" && ok "CLAUDE.md imports AGENTS.md rather than restating it" \
  || no "CLAUDE.md does not import AGENTS.md"

echo "no retired surface travels"
hasnt ".claude/FLOOR.md"                      "FLOOR.md does not travel"
hasnt "agent_docs"                            "agent_docs/ does not travel"
hasnt "specs/templates/t2/spec.thoughts.md"   "spec.thoughts.md does not travel"
hasnt "specs/templates/t2/spec.sessions"      "spec.sessions/ does not travel"
hasnt "specs/templates/t1/spec.context.md"    "*.context.md does not travel"
[ -z "$(find "$T/specs" -name '*.context.md' 2>/dev/null)" ] && ok "no *.context.md anywhere in specs/" || no "a *.context.md travelled"
hasnt ".claude/skills/adopt-harness"          "the adopt tool does not travel"

echo "the gate scaffolding travelled"
has "Makefile"          "base Makefile"
has "make/gate.mk"      "make/gate.mk installed from the requested flavor"
has "specs/README.md"   "specs/ scaffold"

echo "re-running does not clobber filled-in work"
echo "FILLED IN BY THE REPO" >"$T/CLAUDE.md"
echo "FILLED IN BY THE REPO" >"$T/AGENTS.md"
echo "GATE_STEPS = real-checks" >"$T/make/gate.mk"
"$REPO/core/skills/adopt-harness/copy.sh" "$T" python >"$SB/out2" 2>&1 || no "second run failed"
grep -q 'FILLED IN' "$T/CLAUDE.md"        && ok "CLAUDE.md not clobbered"       || no "CLAUDE.md clobbered"
grep -q 'FILLED IN' "$T/AGENTS.md"        && ok "AGENTS.md not clobbered"       || no "AGENTS.md clobbered"
grep -q 'real-checks' "$T/make/gate.mk"   && ok "make/gate.mk not clobbered"    || no "make/gate.mk clobbered"
[ -L "$T/.agents/skills" ] && ok "the symlink survives re-adoption" || no "symlink broken by re-adoption"

echo "bindings MERGE — the smoke failure mode (P1) cannot recur"
# Smoke 2026-08-21: .claude/settings.json existed (repo-owned hooks), .codex/hooks.json did
# not. Fill-once skipped one and created the other — half-governed under a ✅.
T5="$SB/target5"; mkdir -p "$T5/.claude" && git -C "$T5" init -q
cat >"$T5/.claude/settings.json" <<'JSON'
{
  "permissions": {"allow": ["Bash(ls:*)"]},
  "hooks": {
    "PreToolUse": [
      {"matcher": "Edit|MultiEdit|Write",
       "hooks": [{"type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/repo-own-guard.sh"}]}
    ]
  }
}
JSON
if "$REPO/core/skills/adopt-harness/copy.sh" "$T5" none >"$SB/out5" 2>&1; then
  ok "adoption of a repo with a pre-existing settings.json exits 0"
else
  no "adoption failed on pre-existing settings.json"; cat "$SB/out5"
fi
python3 - "$T5" <<'PY' && ok "harness hooks merged into the EXISTING settings.json" || no "harness hooks missing from merged settings.json"
import json,sys,os
d=json.load(open(f"{sys.argv[1]}/.claude/settings.json"))
bound={os.path.basename(h["command"].strip('"')) for gs in d["hooks"].values() for g in gs for h in g["hooks"]}
need={"block-default-branch-commit.sh","block-dangerous-bash.sh","protect-secrets.sh","flag-comment-bloat.sh",
      "enforce-gate-on-stop.sh","ensure-workspace.sh","spec-session-orient.sh","collab-reminders.sh"}
assert need <= bound, need - bound
PY
grep -q 'repo-own-guard' "$T5/.claude/settings.json" && ok "the repo's own hook survives the merge" || no "repo's own hook lost"
grep -q 'Bash(ls:\*)' "$T5/.claude/settings.json" && ok "non-hook keys (permissions) pass through untouched" || no "permissions key damaged"
[ -f "$T5/.codex/hooks.json" ] && ok "the absent Codex binding file is created in the same run" || no ".codex/hooks.json still missing"
cp "$T5/.claude/settings.json" "$SB/m1"; cp "$T5/.codex/hooks.json" "$SB/m2"
"$REPO/core/skills/adopt-harness/copy.sh" "$T5" none >/dev/null 2>&1
cmp -s "$SB/m1" "$T5/.claude/settings.json" && cmp -s "$SB/m2" "$T5/.codex/hooks.json" \
  && ok "the merge is idempotent — a re-run changes neither binding file" || no "re-run mutated a binding file"

echo "the doctor verifies activation (P2) — no ✅ on faith"
grep -q '✅ harness copied and verified active' "$SB/out5" && ok "✅ only after the doctor passes" || no "✅ printed without verification"
"$REPO/core/skills/adopt-harness/copy.sh" --doctor "$T5" >"$SB/doc" 2>&1 && ok "--doctor: green repo exits 0" || no "--doctor red on a healthy repo: $(cat "$SB/doc")"
grep -q 'fires clean' "$SB/doc" && ok "hooks are FIRED against a benign payload, not just listed" || no "no firing evidence in doctor output"
python3 - "$T5" <<'PY'
import json,sys
p=f"{sys.argv[1]}/.codex/hooks.json"; d=json.load(open(p))
d["hooks"]["Stop"]=[]
json.dump(d,open(p,"w"),indent=2)
PY
"$REPO/core/skills/adopt-harness/copy.sh" --doctor "$T5" >"$SB/doc" 2>&1
rc=$?
[ "$rc" -eq 1 ] && grep -q 'NOT BOUND under Stop' "$SB/doc" && ok "--doctor: an unbound hook is exit 1 and NAMED" \
  || no "unbound hook not surfaced (exit $rc): $(cat "$SB/doc")"
"$REPO/core/skills/adopt-harness/copy.sh" "$T5" none >/dev/null 2>&1 \
  && ok "re-adoption heals the unbound hook — the upgrade path is also the repair path" || no "re-adoption did not heal"

echo "refuses to adopt itself"
"$REPO/core/skills/adopt-harness/copy.sh" "$REPO" >/dev/null 2>&1 && no "adopted itself" || ok "refuses self-adoption"

echo "the adoption version stamp (decision O)"
[ -f "$T/.claude/harness-version" ] && ok "stamp written at .claude/harness-version" || no "no stamp"
[ "$(head -1 "$T/.claude/harness-version")" = "$(git -C "$REPO" rev-parse HEAD)" ] \
  && ok "records the harness source commit" || no "stamp does not match the harness HEAD"
"$REPO/core/skills/adopt-harness/copy.sh" --check "$T" >"$SB/chk" 2>&1
[ $? -eq 0 ] && grep -q 'up to date' "$SB/chk" && ok "--check: up to date, exit 0" || no "--check wrong on a fresh adoption: $(cat "$SB/chk")"

echo "staleness is measured, not guessed — against a harness that moves ahead"
# The real repo's history cannot be advanced by a test, so the stamp/check pair runs against a
# disposable mini-harness whose HEAD the test controls.
MH="$SB/mini-harness"
mkdir -p "$MH/core/skills/adopt-harness"
cp -R "$REPO/adopt" "$MH/adopt"
cp "$REPO/core/skills/adopt-harness/"{copy.sh,merge-hook-bindings.py,doctor.py} "$MH/core/skills/adopt-harness/"
git -C "$MH" init -q && git -C "$MH" config user.email t@t && git -C "$MH" config user.name t
git -C "$MH" add -A && git -C "$MH" commit -qm v1
MCP="$MH/core/skills/adopt-harness/copy.sh"
T2="$SB/target2"; mkdir -p "$T2" && git -C "$T2" init -q
"$MCP" "$T2" none >/dev/null 2>&1 || no "mini adoption failed"
"$MCP" --check "$T2" >"$SB/chk" 2>&1
[ $? -eq 0 ] && ok "in step with the mini-harness: exit 0" || no "false staleness right after adoption"
git -C "$MH" commit -qm v2 --allow-empty && git -C "$MH" commit -qm v3 --allow-empty
"$MCP" --check "$T2" >"$SB/chk" 2>&1
rc=$?
[ "$rc" -eq 1 ] && ok "behind: exit 1" || no "behind not signalled (exit $rc)"
grep -q '2 commit(s) behind' "$SB/chk" && ok "counts exactly how far behind" || no "wrong count: $(cat "$SB/chk")"
grep -q 'upgrade path' "$SB/chk" && ok "points at re-adoption as the upgrade path" || no "no upgrade pointer"
"$MCP" "$T2" none >/dev/null 2>&1
"$MCP" --check "$T2" >"$SB/chk" 2>&1
[ $? -eq 0 ] && ok "re-adoption refreshed the stamp — the upgrade path closes the gap" || no "re-adoption left a stale stamp"
rm -f "$T2/.claude/harness-version"
"$MCP" --check "$T2" >"$SB/chk" 2>&1
rc=$?
[ "$rc" -eq 2 ] && grep -q 'no .claude/harness-version' "$SB/chk" && ok "no stamp: exit 2, says so" \
  || no "missing stamp not reported (exit $rc): $(cat "$SB/chk")"

echo "a harness copy without git history still adopts — it just cannot stamp"
NH="$SB/nogit-harness"
mkdir -p "$NH/core/skills/adopt-harness"
cp -R "$REPO/adopt" "$NH/adopt"
cp "$REPO/core/skills/adopt-harness/"{copy.sh,merge-hook-bindings.py,doctor.py} "$NH/core/skills/adopt-harness/"
T3="$SB/target3"; mkdir -p "$T3" && git -C "$T3" init -q
"$NH/core/skills/adopt-harness/copy.sh" "$T3" none >"$SB/out3" 2>&1 && ok "adoption still exits 0" || no "no-git adoption failed"
[ -e "$T3/.claude/harness-version" ] && no "stamped from thin air" || ok "no stamp invented"
grep -q 'no version stamp' "$SB/out3" && ok "and the run says so" || no "silent about the missing stamp"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
