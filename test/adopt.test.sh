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
python3 -c "import json;json.dump({'hooks':{}},open('$T/.claude/settings.json','w'))"
"$REPO/core/skills/adopt-harness/copy.sh" "$T" python >"$SB/out2" 2>&1 || no "second run failed"
grep -q 'FILLED IN' "$T/CLAUDE.md"        && ok "CLAUDE.md not clobbered"       || no "CLAUDE.md clobbered"
grep -q 'FILLED IN' "$T/AGENTS.md"        && ok "AGENTS.md not clobbered"       || no "AGENTS.md clobbered"
grep -q 'real-checks' "$T/make/gate.mk"   && ok "make/gate.mk not clobbered"    || no "make/gate.mk clobbered"
grep -q '"hooks": {}' "$T/.claude/settings.json" && ok "settings.json not clobbered" || no "settings.json clobbered"
[ -L "$T/.agents/skills" ] && ok "the symlink survives re-adoption" || no "symlink broken by re-adoption"

echo "refuses to adopt itself"
"$REPO/core/skills/adopt-harness/copy.sh" "$REPO" >/dev/null 2>&1 && no "adopted itself" || ok "refuses self-adoption"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
