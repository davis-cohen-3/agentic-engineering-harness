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
has ".claude/settings.local.json" ".claude/settings.local.json written (bindings live in LOCAL, never the team file)"
hasnt ".claude/settings.json"     "no .claude/settings.json is created — that file belongs to the repo"
has ".agents/hooks/protect-secrets.sh" "hook scripts landed at .agents/hooks/ (the neutral home)"
[ -x "$T/.agents/hooks/protect-secrets.sh" ] && ok "hooks are executable" || no "hooks not executable"
python3 - "$T" <<'PY' && ok "every Claude hook binding resolves to a real file" || no "a Claude hook binding is dangling"
import json,sys,os,subprocess
t=sys.argv[1]; d=json.load(open(f"{t}/.claude/settings.local.json"))
for ev in d["hooks"].values():
    for g in ev:
        for h in g["hooks"]:
            p=subprocess.check_output(["bash","-c",'echo '+h["command"]],cwd=t,text=True).strip()
            assert os.path.isfile(p), p
PY

echo "discoverable by Codex"
has "AGENTS.md"           "AGENTS.md written (the file Codex reads)"
has ".codex/hooks.json"   ".codex/hooks.json written"
[ -L "$T/.claude/skills" ] && ok ".claude/skills is the adapter symlink" || no ".claude/skills is not a symlink"
[ -d "$T/.agents/skills" ] && [ ! -L "$T/.agents/skills" ] && ok ".agents/skills is the real home directory" || no ".agents/skills is not a real directory"
[ "$(cd "$T/.agents/skills" && pwd -P)" = "$(cd "$T/.claude/skills" && pwd -P)" ] \
  && ok ".agents/skills and .claude/skills are the same directory" || no "symlink points elsewhere"

echo "the briefs are homed at the neutral root, adapters on both sides"
has ".agents/briefs/scout.md"    "briefs landed at .agents/briefs/"
has ".codex/agents/scout.toml"   "Codex pointer tomls landed at .codex/agents/"
grep -q '\.agents/briefs/scout\.md' "$T/.codex/agents/scout.toml" \
  && ok "the toml points at the neutral brief, not a provider path" || no "toml does not reference .agents/briefs/"
[ -L "$T/.claude/agents/scout.md" ] && [ -e "$T/.claude/agents/scout.md" ] \
  && ok ".claude/agents/scout.md is a resolving symlink to the brief" || no ".claude/agents/scout.md is not a resolving symlink"
cmp -s "$T/.claude/agents/scout.md" "$T/.agents/briefs/scout.md" \
  && ok "the symlinked agent reads as the brief" || no "agent/brief content mismatch"
has ".agents/MANIFEST" "the pristine-hash MANIFEST was written"
(cd "$T" && grep -v '^#\|^omitted' .agents/MANIFEST | shasum -c --status) \
  && ok "every MANIFEST hash verifies against the installed entry (shasum -c)" || no "a MANIFEST hash does not verify"

grep -q 'git rev-parse --path-format=absolute --git-common-dir' "$T/.codex/hooks.json" \
  && ok "Codex bindings resolve to the MAIN checkout (worktree-safe), not cwd or an absolute path" \
  || no "Codex bindings not main-checkout-resolved"
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
for ev in d["hooks"].values():
    for g in ev:
        for h in g["hooks"]:
            p=subprocess.check_output(["bash","-c",'echo '+h["command"]],cwd=t,text=True).strip()
            assert os.path.isfile(p), p
PY

echo "bindings survive a WORKTREE — settings are shared through the main checkout, scripts are not"
# The worktree is cut from the pre-adoption commit: untracked payload does NOT travel.
WT="$SB/target-wt"
git -C "$T" worktree add -q "$WT" -b wt-branch 2>/dev/null || no "could not cut a worktree"
[ -e "$WT/.agents/hooks/protect-secrets.sh" ] && no "hook scripts unexpectedly travelled into the worktree" \
  || ok "worktree has no hook scripts of its own (the failure the binding form must survive)"
python3 - "$T" "$WT" <<'PY' && ok "every binding resolved FROM the worktree hits the MAIN checkout's script" || no "a binding dangles when resolved from a worktree"
import json,sys,os,subprocess
t,wt=sys.argv[1],sys.argv[2]
for f in (f"{t}/.claude/settings.local.json", f"{t}/.codex/hooks.json"):
    for ev in json.load(open(f))["hooks"].values():
        for g in ev:
            for h in g["hooks"]:
                p=subprocess.check_output(["bash","-c",'echo '+h["command"]],cwd=wt,text=True).strip()
                assert os.path.isfile(p) and os.path.realpath(p).startswith(os.path.realpath(t)), (f,p)
PY
git -C "$T" worktree remove -f "$WT" >/dev/null 2>&1

echo "SessionStart ordering is load-bearing"
python3 - "$T" <<'PY' && ok "ensure-workspace precedes orientation in BOTH providers" || no "orientation would run before the initialiser"
import json,sys
t=sys.argv[1]
for f in (f"{t}/.claude/settings.local.json", f"{t}/.codex/hooks.json"):
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
[ -L "$T/.claude/skills" ] && ok "the adapter symlink survives re-adoption" || no "symlink broken by re-adoption"

echo "bindings MERGE into settings.local.json — the smoke failure mode (P1) cannot recur"
# Smoke 2026-08-21: .claude/settings.json existed (tracked, team-owned), .codex/hooks.json did
# not. Fill-once skipped one and created the other — half-governed under a ✅. The fix: harness
# Claude bindings live in settings.local.json (untracked), and the team file is NEVER written.
# The team has already bound protect-secrets itself: the sibling pass must not duplicate it.
T5="$SB/target5"; mkdir -p "$T5/.claude" && git -C "$T5" init -q
cat >"$T5/.claude/settings.json" <<'JSON'
{
  "permissions": {"allow": ["Bash(ls:*)"]},
  "hooks": {
    "PreToolUse": [
      {"matcher": "Edit|MultiEdit|Write",
       "hooks": [{"type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/repo-own-guard.sh"},
                 {"type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/protect-secrets.sh"}]}
    ]
  }
}
JSON
cp "$T5/.claude/settings.json" "$SB/team0"
if "$REPO/core/skills/adopt-harness/copy.sh" "$T5" none >"$SB/out5" 2>&1; then
  ok "adoption of a repo with a pre-existing settings.json exits 0"
else
  no "adoption failed on pre-existing settings.json"; cat "$SB/out5"
fi
cmp -s "$SB/team0" "$T5/.claude/settings.json" && ok "the team's settings.json is BYTE-UNTOUCHED" \
  || no "adoption dirtied the team-owned settings.json"
python3 - "$T5" <<'PY' && ok "harness hooks landed in settings.local.json (minus what the team bound)" || no "settings.local.json bindings wrong"
import json,sys,os
d=json.load(open(f"{sys.argv[1]}/.claude/settings.local.json"))
bound={os.path.basename(h["command"].strip('"')) for gs in d["hooks"].values() for g in gs for h in g["hooks"]}
need={"block-default-branch-commit.sh","block-dangerous-bash.sh","flag-comment-bloat.sh",
      "enforce-gate-on-stop.sh","ensure-workspace.sh","spec-session-orient.sh","collab-reminders.sh"}
assert need <= bound, need - bound
assert "protect-secrets.sh" not in bound, "duplicated a hook the team already bound in settings.json"
PY
[ -f "$T5/.codex/hooks.json" ] && ok "the absent Codex binding file is created in the same run" || no ".codex/hooks.json still missing"
cp "$T5/.claude/settings.local.json" "$SB/m1"; cp "$T5/.codex/hooks.json" "$SB/m2"
"$REPO/core/skills/adopt-harness/copy.sh" "$T5" none >/dev/null 2>&1
cmp -s "$SB/m1" "$T5/.claude/settings.local.json" && cmp -s "$SB/m2" "$T5/.codex/hooks.json" \
  && ok "the merge is idempotent — a re-run changes neither binding file" || no "re-run mutated a binding file"
python3 - "$T5" <<'PY'
import json,sys
p=f"{sys.argv[1]}/.claude/settings.local.json"; d=json.load(open(p))
for gs in d["hooks"].values():
    for g in gs:
        for h in g["hooks"]:
            if "collab-reminders" in h["command"]:
                h["command"]="$CLAUDE_PROJECT_DIR/.claude/hooks/collab-reminders.sh"
json.dump(d,open(p,"w"),indent=2)
PY
"$REPO/core/skills/adopt-harness/copy.sh" "$T5" none >"$SB/out6" 2>&1
grep -q 'updated 1 stale command' "$SB/out6" && ok "a stale command form in OUR file is upgraded in place" \
  || no "stale command not upgraded: $(grep 'settings.local' "$SB/out6")"
grep -q 'CLAUDE_PROJECT_DIR' "$T5/.claude/settings.local.json" && no "old command form survived the upgrade" \
  || ok "no stale form left behind"

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
[ -f "$T/.agents/harness-version" ] && ok "stamp written at .agents/harness-version" || no "no stamp"
[ "$(head -1 "$T/.agents/harness-version")" = "$(git -C "$REPO" rev-parse HEAD)" ] \
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
rm -f "$T2/.agents/harness-version"
"$MCP" --check "$T2" >"$SB/chk" 2>&1
rc=$?
[ "$rc" -eq 2 ] && grep -q 'no .agents/harness-version' "$SB/chk" && ok "no stamp: exit 2, says so" \
  || no "missing stamp not reported (exit $rc): $(cat "$SB/chk")"

echo "a harness copy without git history still adopts — it just cannot stamp"
NH="$SB/nogit-harness"
mkdir -p "$NH/core/skills/adopt-harness"
cp -R "$REPO/adopt" "$NH/adopt"
cp "$REPO/core/skills/adopt-harness/"{copy.sh,merge-hook-bindings.py,doctor.py} "$NH/core/skills/adopt-harness/"
T3="$SB/target3"; mkdir -p "$T3" && git -C "$T3" init -q
"$NH/core/skills/adopt-harness/copy.sh" "$T3" none >"$SB/out3" 2>&1 && ok "adoption still exits 0" || no "no-git adoption failed"
[ -e "$T3/.agents/harness-version" ] && no "stamped from thin air" || ok "no stamp invented"
grep -q 'no version stamp' "$SB/out3" && ok "and the run says so" || no "silent about the missing stamp"

echo "MANAGED entries update by THREE-WAY comparison (the ratified state table)"
"$MCP" "$T2" none >/dev/null 2>&1 || no "re-adoption to restore T2 failed"
CR="$T2/.agents/hooks/collab-reminders.sh"

printf '\n# local tuning\n' >>"$CR"
"$MCP" "$T2" none >"$SB/tw1" 2>&1
[ $? -eq 0 ] && ok "a local-only edit does not fail the run" || no "local-only edit failed the run: $(tail -3 "$SB/tw1")"
grep -q '1 held' "$SB/tw1" && ok "…and is COUNTED as held" || no "held count wrong: $(grep managed "$SB/tw1")"
grep -q '# local tuning' "$CR" && ok "…and the local edit survives" || no "local edit clobbered"

printf '\n# upstream v4\n' >>"$MH/adopt/hooks/flag-comment-bloat.sh"
git -C "$MH" commit -qam v4
"$MCP" "$T2" none >"$SB/tw2" 2>&1 || no "refresh run failed: $(tail -3 "$SB/tw2")"
grep -q '# upstream v4' "$T2/.agents/hooks/flag-comment-bloat.sh" \
  && ok "an untouched entry is refreshed from upstream" || no "refresh did not land"
grep -q '1 held' "$SB/tw2" && ok "the held entry is still held, not clobbered by the refresh pass" || no "held entry lost"

printf '\n# upstream v5\n' >>"$MH/adopt/hooks/collab-reminders.sh"
git -C "$MH" commit -qam v5
"$MCP" "$T2" none >"$SB/tw3" 2>&1
rc=$?
[ "$rc" -eq 1 ] && ok "both-changed → exit 1, never silent" || no "both-changed did not fail (exit $rc)"
grep -q 'BOTH changed' "$SB/tw3" && ok "…the conflict is NAMED" || no "conflict not named"
grep -q '# upstream v5' "$CR" && no "conflict silently took upstream" || ok "…and the local version is KEPT"
grep -q -- '--resolve' "$SB/tw3" && ok "…and the run prints the resolution paths" || no "no resolution guidance"
"$MCP" --check "$T2" >"$SB/tw4" 2>&1
rc=$?
[ "$rc" -eq 1 ] && grep -qi 'conflict' "$SB/tw4" && ok "--check surfaces entry conflicts without copying" \
  || no "--check missed the conflict (exit $rc): $(cat "$SB/tw4")"

"$MCP" --resolve ".agents/hooks/collab-reminders.sh=upstream" "$T2" none >"$SB/tw5" 2>&1 \
  && ok "--resolve …=upstream exits 0" || no "resolve upstream failed: $(tail -3 "$SB/tw5")"
grep -q '# upstream v5' "$CR" && ok "…and the harness version landed" || no "upstream version did not land"
"$MCP" "$T2" none >/dev/null 2>&1 && ok "…and the next plain run is clean" || no "still conflicted after resolution"

echo "CRITICAL entries fail closed — the security-fix scenario"
PS="$T2/.agents/hooks/protect-secrets.sh"
printf '\n# local guard tweak\n' >>"$PS"
printf '\n# upstream security fix\n' >>"$MH/adopt/hooks/protect-secrets.sh"
git -C "$MH" commit -qam v6
"$MCP" "$T2" none >"$SB/tw7" 2>&1
rc=$?
[ "$rc" -eq 1 ] && grep -q 'CRITICAL' "$SB/tw7" && ok "a critical conflict blocks and carries the CRITICAL marker" \
  || no "critical conflict not marked (exit $rc)"
"$MCP" --resolve ".agents/hooks/protect-secrets.sh=local" "$T2" none >/dev/null 2>&1 \
  && ok "resolved =local: run passes" || no "resolve local failed"
grep -q '# local guard tweak' "$PS" && ok "…the repo's version stays in place" || no "local version lost"
printf '\n# upstream v7\n' >>"$MH/adopt/hooks/protect-secrets.sh"
git -C "$MH" commit -qam v7
"$MCP" "$T2" none >"$SB/tw8" 2>&1
[ $? -eq 1 ] && grep -q 'CRITICAL' "$SB/tw8" \
  && ok "a NEW upstream fix to a resolved-local entry conflicts AGAIN — a new fix needs a new decision" \
  || no "the follow-up security fix was silently dropped"
"$MCP" --resolve ".agents/hooks/protect-secrets.sh=upstream" "$T2" none >/dev/null 2>&1
grep -q '# upstream v7' "$PS" && ok "…and =upstream takes it" || no "fix still not applied"

echo "a deliberate deletion is a tombstone"
TMPL="$(cd "$MH" && find adopt/specs/templates -type f | head -1)"
TMPL_DST="specs/${TMPL#adopt/specs/}"
rm "$T2/$TMPL_DST"
"$MCP" "$T2" none >"$SB/tw9" 2>&1
[ $? -eq 1 ] && grep -q 'missing' "$SB/tw9" && ok "a missing managed entry is a conflict, not a reinstall or a shrug" \
  || no "deletion not surfaced"
"$MCP" --resolve "$TMPL_DST=omit" "$T2" none >/dev/null 2>&1 && ok "--resolve …=omit accepted" || no "omit failed"
[ ! -e "$T2/$TMPL_DST" ] && ok "…the file stays gone" || no "omit reinstalled the file"
"$MCP" "$T2" none >/dev/null 2>&1 && [ ! -e "$T2/$TMPL_DST" ] \
  && ok "…and stays gone across re-adoption (tombstoned)" || no "tombstone did not hold"

echo "bootstrap onto existing content — the armed-clobber case can no longer fire"
T4="$SB/target4"; mkdir -p "$T4/make" && git -C "$T4" init -q
cp "$MH/adopt/Makefile" "$T4/Makefile"                          # identical → adopted quietly
echo "REPO'S OWN CONTENT" >"$T4/make/gate.example-python.mk"    # differs → conflict, not clobber
"$MCP" "$T4" none >"$SB/tw10" 2>&1
rc=$?
[ "$rc" -eq 1 ] && grep -q 'gate.example-python.mk' "$SB/tw10" \
  && ok "a pre-existing differing file CONFLICTS instead of being overwritten" || no "bootstrap clobber guard failed (exit $rc)"
grep -q "REPO'S OWN CONTENT" "$T4/make/gate.example-python.mk" && ok "…and its content is untouched" || no "content clobbered"
"$MCP" --resolve "make/gate.example-python.mk=local" "$T4" none >/dev/null 2>&1 \
  && ok "…resolvable as the repo's own (=local)" || no "bootstrap resolve failed"

echo "a pre-neutral-root repo is MIGRATED in place"
T6="$SB/target6"; mkdir -p "$T6/.claude/hooks" "$T6/.claude/skills/myskill" "$T6/.claude/agents" "$T6/.agents"
git -C "$T6" init -q
cp "$MH"/adopt/hooks/*.sh "$T6/.claude/hooks/"                  # old home, unmodified copies
printf '\n# melting-style local tuning\n' >>"$T6/.claude/hooks/ensure-workspace.sh"   # …except one
echo "repo skill" >"$T6/.claude/skills/myskill/SKILL.md"        # skills really lived in .claude
ln -s ../.claude/skills "$T6/.agents/skills"                    # the old inverse link
cp "$MH/adopt/agents/scout.md" "$T6/.claude/agents/scout.md"    # brief as a real duplicate file
cp "$MH/adopt/agents/reviewer.md" "$T6/.claude/agents/reviewer.md"
printf '\nRepo-tuned addendum.\n' >>"$T6/.claude/agents/reviewer.md"                  # …and a tuned one
echo deadbeef >"$T6/.claude/harness-version"                    # the old stamp location
"$MCP" "$T6" none >"$SB/tw11" 2>&1 || no "migration adoption failed: $(tail -5 "$SB/tw11")"
[ -L "$T6/.claude/skills" ] && [ -d "$T6/.agents/skills" ] && [ ! -L "$T6/.agents/skills" ] \
  && ok "the skills link is INVERTED: home at .agents/skills, adapter at .claude/skills" || no "inversion failed"
[ -f "$T6/.agents/skills/myskill/SKILL.md" ] && ok "…the repo's skills moved with it" || no "repo skill lost in the move"
[ -L "$T6/.claude/agents/scout.md" ] && ok "the duplicate brief file became a symlink" || no "brief not linked"
[ ! -e "$T6/.claude/hooks/protect-secrets.sh" ] && ok "unmodified old hook copies are removed" || no "old hook copy lingers"
grep -q '# melting-style local tuning' "$T6/.agents/hooks/ensure-workspace.sh" \
  && ok "an EDITED old-home hook carried its edits to .agents/hooks/ — behavior preserved" \
  || no "the edited hook was replaced by the harness version"

echo "a repo that git-TRACKS .claude/skills keeps it as the home"
# Found in the wild 2026-08-22: smoke tracks its skills at .claude/skills. The inversion would
# have staged 17 tracked files for deletion on a repo the operator does not administer.
T7="$SB/target7"; mkdir -p "$T7/.claude/skills/teamskill"
git -C "$T7" init -q
echo "team skill" >"$T7/.claude/skills/teamskill/SKILL.md"
git -C "$T7" add -A >/dev/null 2>&1
git -C "$T7" -c user.email=t@t -c user.name=t commit -qm init >/dev/null 2>&1
"$MCP" "$T7" none >"$SB/tw12" 2>&1 || no "tracked-skills adoption failed: $(tail -5 "$SB/tw12")"
[ -d "$T7/.claude/skills" ] && [ ! -L "$T7/.claude/skills" ] \
  && ok "the TRACKED .claude/skills stayed a real directory" || no "a tracked skills home was moved"
[ -L "$T7/.agents/skills" ] && [ -e "$T7/.agents/skills" ] \
  && ok "…and .agents/skills points at it, so Codex still resolves" || no ".agents/skills is not a resolving link"
[ -f "$T7/.claude/skills/teamskill/SKILL.md" ] && ok "…the team's skill file survived" || no "tracked skill lost"
[ -z "$(git -C "$T7" status --porcelain | grep "^ *D")" ] \
  && ok "…and NOTHING tracked was staged for deletion" || no "adoption staged a deletion of tracked files"
grep -q "TRACKED files" "$SB/tw12" && ok "…and it said why" || no "the refusal was silent"

echo "when BOTH skills homes are tracked, neither is touched"
T8="$SB/target8"; mkdir -p "$T8/.claude/skills/a" "$T8/.agents/skills/b"
git -C "$T8" init -q
echo "a" >"$T8/.claude/skills/a/SKILL.md"; echo "b" >"$T8/.agents/skills/b/SKILL.md"
git -C "$T8" add -A >/dev/null 2>&1
git -C "$T8" -c user.email=t@t -c user.name=t commit -qm init >/dev/null 2>&1
"$MCP" "$T8" none >"$SB/tw13" 2>&1 || true
[ -f "$T8/.claude/skills/a/SKILL.md" ] && [ -f "$T8/.agents/skills/b/SKILL.md" ] \
  && ok "both tracked homes were left intact" || no "a tracked skills home was clobbered"
[ -z "$(git -C "$T8" status --porcelain | grep "^ *D")" ] \
  && ok "…and nothing was staged for deletion" || no "adoption staged a deletion"
grep -q "BOTH" "$SB/tw13" && ok "…and the ambiguity was named" || no "the two-home case was silent"
[ ! -d "$T6/.claude/hooks" ] && ok "…and the emptied .claude/hooks/ is gone" || no ".claude/hooks/ left behind"
grep -q 'Repo-tuned addendum' "$T6/.agents/briefs/reviewer.md" && [ -L "$T6/.claude/agents/reviewer.md" ] \
  && ok "a TUNED brief carried its edits to .agents/briefs/ and got the symlink" \
  || no "the tuned brief was not carried forward"
[ ! -e "$T6/.claude/harness-version" ] && [ -f "$T6/.agents/harness-version" ] \
  && ok "the stamp moved to .agents/harness-version" || no "stamp migration failed"
"$MCP" "$T6" none >"$SB/tw12" 2>&1 && grep -q '2 held' "$SB/tw12" \
  && ok "…and the next run counts both carried edits as HELD" || no "carried edits not held: $(grep managed "$SB/tw12")"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
