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
      "ensure-workspace.sh","spec-session-orient.sh","collab-reminders.sh"}
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
d["hooks"]["UserPromptSubmit"]=[]
json.dump(d,open(p,"w"),indent=2)
PY
"$REPO/core/skills/adopt-harness/copy.sh" --doctor "$T5" >"$SB/doc" 2>&1
rc=$?
[ "$rc" -eq 1 ] && grep -q 'NOT BOUND under UserPromptSubmit' "$SB/doc" && ok "--doctor: an unbound hook is exit 1 and NAMED" \
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
cp "$REPO/core/skills/adopt-harness/"{copy.sh,*.py} "$MH/core/skills/adopt-harness/"
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
cp "$REPO/core/skills/adopt-harness/"{copy.sh,*.py} "$NH/core/skills/adopt-harness/"
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

# bound <file> <needle> → how many hook commands in <file> contain <needle>
bound() { python3 - "$1" "$2" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
print(sum(sys.argv[2] in h["command"] for gs in d.get("hooks",{}).values() for g in gs for h in g.get("hooks",[])))
PY
}
has_event() { python3 -c 'import json,sys; sys.exit(0 if sys.argv[2] in json.load(open(sys.argv[1])).get("hooks",{}) else 1)' "$1" "$2"; }

echo "an OMITTED hook is a per-target exemption — a neutral doctor row, never a red one"
# Found re-adopting melting v3 (2026-09-19): it omits the harness route-worktree.sh because it
# binds WorktreeCreate to its OWN scripts/route-worktree.sh — same basename, different path. The
# doctor read its expectations from the payload alone, so the sanctioned =omit could never reach ✅.
T9="$SB/target9"; mkdir -p "$T9/.claude" "$T9/scripts" && git -C "$T9" init -q
printf '#!/usr/bin/env bash\nexit 0\n' >"$T9/scripts/route-worktree.sh"; chmod +x "$T9/scripts/route-worktree.sh"
cat >"$T9/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "WorktreeCreate": [
      {"hooks": [{"type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/scripts/route-worktree.sh\""}]}
    ]
  }
}
JSON
cp "$T9/.claude/settings.json" "$SB/team9"
"$MCP" "$T9" none >/dev/null 2>&1 || no "melting-shaped adoption failed"
"$MCP" --resolve ".agents/hooks/route-worktree.sh=omit" "$T9" none >"$SB/om1" 2>&1 \
  && ok "a run that omits a hook exits 0" || no "omit run failed: $(tail -4 "$SB/om1")"
grep -q '✅ harness copied and verified active' "$SB/om1" && ok "…and reaches the ✅" || no "no ✅ after a sanctioned omit"
grep -Eq '– route-worktree\.sh +omitted by this repo' "$SB/om1" \
  && ok "the doctor names the omitted hook on a NEUTRAL row" || no "no neutral row: $(grep route-worktree "$SB/om1")"
grep -q '✗ route-worktree.sh' "$SB/om1" && no "the omitted hook is still a red row" || ok "…and not on a red one"
grep -q 'doctor: .*1 omitted by this repo' "$SB/om1" \
  && ok "the green summary COUNTS the omission instead of claiming every hook is active" || no "summary hides the omission: $(grep '^doctor:' "$SB/om1")"
cmp -s "$SB/team9" "$T9/.claude/settings.json" \
  && ok "the repo's OWN same-basename binding (scripts/route-worktree.sh) is byte-untouched" || no "the repo's own binding was rewritten"
"$MCP" "$T9" none >/dev/null 2>&1 && "$MCP" --doctor "$T9" >/dev/null 2>&1 \
  && ok "…and the tombstone keeps plain re-adoption and --doctor green" || no "the exemption did not hold across runs"

echo "omitting a hook UNBINDS it — a tombstone and a live binding to the same script cannot coexist"
# Without this the neutral row would be a lie: =omit deleted the script but left the binding the
# first adoption wrote, so the provider ran a missing file on every event.
T10="$SB/target10"; mkdir -p "$T10" && git -C "$T10" init -q
"$MCP" "$T10" none >/dev/null 2>&1 || no "T10 adoption failed"
"$MCP" --resolve ".agents/hooks/collab-reminders.sh=omit" "$T10" none >"$SB/om2" 2>&1 \
  && ok "omitting a hook the first adoption BOUND exits 0" || no "omit of a bound hook failed: $(tail -4 "$SB/om2")"
[ "$(bound "$T10/.claude/settings.local.json" collab-reminders)" = 0 ] && [ "$(bound "$T10/.codex/hooks.json" collab-reminders)" = 0 ] \
  && ok "its binding is gone from BOTH providers' files" || no "an omitted hook is still bound"
has_event "$T10/.claude/settings.local.json" UserPromptSubmit || has_event "$T10/.codex/hooks.json" UserPromptSubmit \
  && no "an emptied event key was left behind" || ok "…and the event key it emptied is deleted"
[ "$(grep -Ec '– collab-reminders\.sh +omitted by this repo' "$SB/om2")" = 2 ] \
  && ok "the neutral row appears under each provider that expected it" || no "neutral rows wrong: $(grep collab "$SB/om2")"
cp "$T10/.claude/settings.local.json" "$SB/o1"; cp "$T10/.codex/hooks.json" "$SB/o2"
"$MCP" "$T10" none >/dev/null 2>&1 || no "re-adoption after omit failed"
cmp -s "$SB/o1" "$T10/.claude/settings.local.json" && cmp -s "$SB/o2" "$T10/.codex/hooks.json" \
  && ok "re-adoption does NOT re-bind an omitted hook — neither file changes" || no "the merge re-bound an omitted hook"

echo "a hook missing WITHOUT a tombstone is still red — the exemption is the tombstone, not the absence"
rm "$T10/.agents/hooks/flag-comment-bloat.sh"
"$MCP" --doctor "$T10" >"$SB/om3" 2>&1
rc=$?
[ "$rc" -eq 1 ] && grep -Eq '✗ flag-comment-bloat\.sh +script missing' "$SB/om3" \
  && ok "--doctor: exit 1 and the missing script is NAMED" || no "untombstoned deletion not red (exit $rc): $(grep flag-comment "$SB/om3")"
"$MCP" "$T10" none >/dev/null 2>&1
[ $? -eq 1 ] && [ "$(bound "$T10/.claude/settings.local.json" flag-comment-bloat)" = 1 ] && [ "$(bound "$T10/.codex/hooks.json" flag-comment-bloat)" = 1 ] \
  && ok "…and an ACCIDENTAL deletion never unbinds — the guard stays bound for the restore" || no "a conflicted-missing hook lost its binding"
"$MCP" --resolve ".agents/hooks/flag-comment-bloat.sh=upstream" "$T10" none >/dev/null 2>&1 \
  && ok "…which =upstream then completes" || no "restore after accidental deletion failed"

echo "a hook the harness RETIRES takes its bindings with it"
# Harness #19 retired enforce-gate-on-stop.sh. Re-adoption pruned the script, but the merge only
# ever ADDED, so both providers kept a Stop binding to a file that no longer existed — and the
# doctor, checking only what the payload expects, stayed green. Three targets, one retirement:
HCMD='"$(git rev-parse --path-format=absolute --git-common-dir)/../.agents/hooks/collab-reminders.sh"'
T11="$SB/target11"; T12="$SB/target12"; T13="$SB/target13"
for t in "$T11" "$T12" "$T13"; do mkdir -p "$t/.claude" && git -C "$t" init -q; done
# T12 is melting #102's shape: the team TRACKS the harness bindings in its own settings.json.
python3 - "$T12" "$HCMD" <<'PY'
import json,sys
json.dump({"hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":sys.argv[2]}]}]}},
          open(f"{sys.argv[1]}/.claude/settings.json","w"),indent=2)
PY
cp "$T12/.claude/settings.json" "$SB/team12"
for t in "$T11" "$T12" "$T13"; do "$MCP" "$t" none >/dev/null 2>&1 || no "pre-retirement adoption of $(basename "$t") failed"; done
[ "$(bound "$T12/.claude/settings.local.json" collab-reminders)" = 0 ] || no "T12 setup: the team's binding was duplicated into settings.local.json"
# T11 carries the repo's OWN entries beside the harness one: the same basename at the repo's own
# path, the same basename in a NESTED repo's hook home, and its own script in the shared home.
printf '#!/usr/bin/env bash\nexit 0\n' >"$T11/.agents/hooks/repo-own-guard.sh"; chmod +x "$T11/.agents/hooks/repo-own-guard.sh"
python3 - "$T11" <<'PY'
import json,sys
p=f"{sys.argv[1]}/.claude/settings.local.json"; d=json.load(open(p))
d["hooks"]["UserPromptSubmit"].append({"hooks":[
  {"type":"command","command":'"$CLAUDE_PROJECT_DIR"/scripts/collab-reminders.sh'},
  {"type":"command","command":'"$CLAUDE_PROJECT_DIR"/packages/sub/.agents/hooks/collab-reminders.sh'},
  {"type":"command","command":'"$CLAUDE_PROJECT_DIR"/.agents/hooks/repo-own-guard.sh'}]})
json.dump(d,open(p,"w"),indent=2)
PY
printf '\n# local tuning\n' >>"$T13/.agents/hooks/collab-reminders.sh"   # T13: retired upstream, EDITED here

git -C "$MH" rm -q adopt/hooks/collab-reminders.sh
python3 - "$MH" <<'PY'
import json,sys
for f in ("adopt/settings.json","adopt/codex/hooks.json"):
    p=f"{sys.argv[1]}/{f}"; d=json.load(open(p)); del d["hooks"]["UserPromptSubmit"]
    json.dump(d,open(p,"w"),indent=2)
PY
git -C "$MH" commit -qam "retire collab-reminders"

"$MCP" "$T11" none >"$SB/rt1" 2>&1 && ok "re-adoption across a retirement exits 0" || no "retirement run failed: $(tail -4 "$SB/rt1")"
grep -q 'collab-reminders.sh pruned (removed upstream)' "$SB/rt1" && [ ! -e "$T11/.agents/hooks/collab-reminders.sh" ] \
  && ok "the unmodified script is pruned (unchanged behaviour)" || no "script not pruned"
[ "$(bound "$T11/.claude/settings.local.json" '/../.agents/hooks/collab-reminders.sh')" = 0 ] \
  && [ "$(bound "$T11/.codex/hooks.json" collab-reminders)" = 0 ] \
  && ok "…and its binding is removed from BOTH providers' files" || no "a dangling binding to the pruned script survives"
[ "$(grep -c 'removed 1 dead binding' "$SB/rt1")" = 2 ] && ok "…and each file's summary line says so" || no "removal not reported: $(grep -E 'settings.local|hooks.json' "$SB/rt1")"
has_event "$T11/.codex/hooks.json" UserPromptSubmit && no "the event key the prune emptied was left behind" || ok "an event key that becomes empty is deleted"
python3 - "$T11" <<'PY' && ok "the repo's OWN entries survive verbatim — same basename elsewhere, a nested hook home, its own script" || no "the prune touched a repo-owned binding"
import json,sys
d=json.load(open(f"{sys.argv[1]}/.claude/settings.local.json"))
got=[h["command"] for g in d["hooks"]["UserPromptSubmit"] for h in g["hooks"]]
assert got==['"$CLAUDE_PROJECT_DIR"/scripts/collab-reminders.sh',
             '"$CLAUDE_PROJECT_DIR"/packages/sub/.agents/hooks/collab-reminders.sh',
             '"$CLAUDE_PROJECT_DIR"/.agents/hooks/repo-own-guard.sh'], got
PY
grep -q '✅ harness copied and verified active' "$SB/rt1" && ok "…under a green doctor" || no "no ✅ after the retirement run"
cp "$T11/.claude/settings.local.json" "$SB/r1"; cp "$T11/.codex/hooks.json" "$SB/r2"
"$MCP" "$T11" none >/dev/null 2>&1
cmp -s "$SB/r1" "$T11/.claude/settings.local.json" && cmp -s "$SB/r2" "$T11/.codex/hooks.json" \
  && ok "the next run changes neither binding file (still idempotent)" || no "re-run mutated a binding file"

echo "…but a dead binding in the TEAM's settings.json is reported, never edited (#12 holds)"
"$MCP" "$T12" none >"$SB/rt2" 2>&1
rc=$?
cmp -s "$SB/team12" "$T12/.claude/settings.json" && ok "the team's settings.json is BYTE-UNTOUCHED" || no "the prune dirtied the team-owned settings.json"
grep -q '\.claude/settings\.json' "$SB/rt2" && grep -qF -- "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$HCMD")" "$SB/rt2" \
  && ok "the run names the file and prints the EXACT entry to remove" || no "no hand-removal instruction: $(grep -n settings.json "$SB/rt2")"
[ "$rc" -eq 1 ] && grep -Eq '✗ collab-reminders\.sh +bound under UserPromptSubmit in \.claude/settings\.json' "$SB/rt2" \
  && ok "…and the doctor holds the ✅ back on a red row, though the payload no longer expects the hook" \
  || no "dangling team binding not red (exit $rc): $(grep -n collab "$SB/rt2")"
# The retiring run is the only one that knows the hook was pruned; the record is gone after it.
# The entry to delete must not vanish with it — the doctor reads it off the file every time.
HJSON="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$HCMD")"
"$MCP" "$T12" none >"$SB/rt2b" 2>&1
[ $? -eq 1 ] && grep -qF -- "\"command\": $HJSON" "$SB/rt2b" \
  && ok "a LATER run, with nothing fixed, still prints the exact entry (the advisory is not one-shot)" \
  || no "the exact entry vanished after the retiring run: $(grep -n collab "$SB/rt2b")"
"$MCP" --doctor "$T12" >"$SB/rt2c" 2>&1
grep -qF -- "\"command\": $HJSON" "$SB/rt2c" && ok "…and so does --doctor on its own" || no "--doctor names the binding but not the entry"
python3 - "$T12" <<'PY'
import json,sys
p=f"{sys.argv[1]}/.claude/settings.json"; d=json.load(open(p)); del d["hooks"]["UserPromptSubmit"]
json.dump(d,open(p,"w"),indent=2)
PY
"$MCP" "$T12" none >/dev/null 2>&1 && ok "removing that entry by hand is all it takes to go green" || no "still red after the hand edit"

echo "…and a retired hook the repo EDITED keeps its binding — the script is still there"
"$MCP" "$T13" none >"$SB/rt3" 2>&1 && ok "the run exits 0" || no "edited-retired run failed: $(tail -4 "$SB/rt3")"
grep -q 'collab-reminders.sh removed upstream but locally modified' "$SB/rt3" && [ -f "$T13/.agents/hooks/collab-reminders.sh" ] \
  && ok "the edited script is left as the repo's own (unchanged behaviour)" || no "edited script not kept"
[ "$(bound "$T13/.claude/settings.local.json" collab-reminders)" = 1 ] && [ "$(bound "$T13/.codex/hooks.json" collab-reminders)" = 1 ] \
  && ok "…and both bindings to it are left alone" || no "a binding to a surviving script was removed"

echo "the doctor flags ANY binding into .agents/hooks/ whose script is missing — and adoption never guesses"
# A name the harness has no record of (here: what an older copy.sh left behind after #19) cannot be
# told from the repo's own hook, so it is reported for a hand edit, not removed.
python3 - "$T11" <<'PY'
import json,sys
p=f"{sys.argv[1]}/.codex/hooks.json"; d=json.load(open(p))
d["hooks"]["Stop"]=[{"hooks":[{"type":"command","command":'"$(git rev-parse --path-format=absolute --git-common-dir)/../.agents/hooks/enforce-gate-on-stop.sh"'}]}]
json.dump(d,open(p,"w"),indent=2)
PY
"$MCP" --doctor "$T11" >"$SB/rt4" 2>&1
rc=$?
[ "$rc" -eq 1 ] && grep -Eq '✗ enforce-gate-on-stop\.sh +bound under Stop in \.codex/hooks\.json' "$SB/rt4" \
  && ok "--doctor: exit 1, naming the script, the event and the file" || no "unexpected dangling binding not red (exit $rc): $(cat "$SB/rt4")"
"$MCP" "$T11" none >/dev/null 2>&1
[ $? -eq 1 ] && [ "$(bound "$T11/.codex/hooks.json" enforce-gate-on-stop)" = 1 ] \
  && ok "…and re-adoption leaves an entry it has no record of, staying red until a human decides" || no "adoption removed a binding it never managed"

echo "what counts as a binding into the hook home — the rule the merge REMOVES on"
python3 - "$REPO/core/skills/adopt-harness" <<'PY' && ok "root expressions match; the repo's own paths, a nested hook home and wrappers with arguments do not" || no "homed_script misjudged a command form"
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
from bindings import homed_script as h
ours = ['"$(git rev-parse --path-format=absolute --git-common-dir)/../.agents/hooks/x.sh"',
        '"$CLAUDE_PROJECT_DIR"/.agents/hooks/x.sh', 'bash "$CLAUDE_PROJECT_DIR/.agents/hooks/x.sh"',
        '$(git rev-parse --show-toplevel)/.agents/hooks/x.sh', '.agents/hooks/x.sh', 'bash ./.agents/hooks/x.sh']
theirs = ['bash "$CLAUDE_PROJECT_DIR/scripts/x.sh"', '"$CLAUDE_PROJECT_DIR"/.claude/hooks/x.sh',
          '"$CLAUDE_PROJECT_DIR"/packages/sub/.agents/hooks/x.sh', 'vendor/.agents/hooks/x.sh',
          '/abs/repo/.agents/hooks/x.sh', '"$CLAUDE_PROJECT_DIR"/.agents/hooks/x.sh --flag', 'npx prettier .', '',
          # a shell metacharacter glued to the name must not become PART of the name
          '"$CLAUDE_PROJECT_DIR"/.agents/hooks/x.sh;', '(cd a && "$CLAUDE_PROJECT_DIR"/.agents/hooks/x.sh)',
          '"$CLAUDE_PROJECT_DIR"/.agents/hooks/x.sh&', '"$CLAUDE_PROJECT_DIR"/.agents/hooks/x.sh|| true',
          '"$CLAUDE_PROJECT_DIR"/.agents/hooks/x.sh>/dev/null']
assert [h(c) for c in ours] == ["x.sh"] * len(ours), [c for c in ours if h(c) != "x.sh"]
assert [h(c) for c in theirs] == [None] * len(theirs), [c for c in theirs if h(c)]
PY
# install.sh publishes core/ byte-for-byte and inventories ~/.agents/ for drift; the suite above
# has just run both scripts dozens of times, so any bytecode they write is sitting here now.
[ ! -e "$MH/core/skills/adopt-harness/__pycache__" ] && [ ! -e "$REPO/core/skills/adopt-harness/__pycache__" ] \
  && ok "the skill's Python leaves no __pycache__/ beside itself" || no "a __pycache__/ was written into the published skill directory"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
