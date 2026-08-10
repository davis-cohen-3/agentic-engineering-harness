#!/usr/bin/env bash
# Acceptance test for ensure-workspace.sh and wt (plan/tasks.md T0.7).
#
# Everything runs against disposable git repos in a temp dir, including a fake "origin" served
# from a bare repo, so no real project or remote is touched.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EW="$REPO/adopt/hooks/ensure-workspace.sh"
WT="$REPO/bin/wt"
SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT

# wt resolves the repo from the cwd and the project from ${XDG_CONFIG_HOME}/agents/projects.yaml.
# Point both at the sandbox: without this, a wt invocation that forgets to cd resolves against the
# REAL registry and cuts a real worktree in a real project. That is not hypothetical — it happened
# on the first run of this file.
export XDG_CONFIG_HOME="$SB/config"
mkdir -p "$XDG_CONFIG_HOME/agents"
cd "$SB"

pass=0 fail=0
ok() { pass=$((pass+1)); printf '  ✓ %s\n' "$1"; }
no() { fail=$((fail+1)); printf '  ✗ %s\n' "$1"; }
is() { [ "$2" = "$3" ] && ok "$1" || no "$1 (got '$2', want '$3')"; }

echo "T0.7 — ensure-workspace.sh and wt"

# ── a disposable repo with a real origin
mkdir -p "$SB/origin" && git -C "$SB/origin" init -q --bare
git clone -q "$SB/origin" "$SB/proj" 2>/dev/null
git -C "$SB/proj" config user.email t@t; git -C "$SB/proj" config user.name t
# CONTRACT §2: .workspace/ is excluded via the GLOBAL gitignore and no repo .gitignore mentions
# it. Model that here — without it `git add -A` commits .workspace/ and every new worktree
# inherits another worktree's task memory from origin/main.
printf '.workspace/\n' >"$SB/gitignore-global"
git -C "$SB/proj" config core.excludesFile "$SB/gitignore-global"
printf 'setup:\n\t@echo setup-ran > setup.log\n' >"$SB/proj/Makefile"
git -C "$SB/proj" add -A && git -C "$SB/proj" commit -qm init
git -C "$SB/proj" branch -M main && git -C "$SB/proj" push -q origin main

echo "ensure-workspace.sh"
( cd "$SB/proj" && "$EW" >/dev/null 2>&1 )
[ -f "$SB/proj/.workspace/MISSION.md" ] && ok "creates .workspace/MISSION.md" || no "no MISSION.md"
grep -q '^state: scoping' "$SB/proj/.workspace/MISSION.md" && ok "defaults to state: scoping" || no "wrong default state"
grep -q '^spec: null'     "$SB/proj/.workspace/MISSION.md" && ok "defaults to spec: null"     || no "wrong default spec"

# The report path must parse the very template the create path writes: its inline comment
# ('spec: null   # or specs/<slug>.md') once read as a dangling spec pointer, so every
# SessionStart after the first warned about a spec named 'null   # or specs/<slug>.md'.
out="$( cd "$SB/proj" && "$EW" 2>&1 )"
[ -z "$out" ] && ok "silent when re-run over its own default template" || no "warned on its own template: $out"

mkdir -p "$SB/proj/specs" && : >"$SB/proj/specs/real.md"
printf -- '---\nstate: building\nspec: specs/real.md   # picked in session 3\n---\n' >"$SB/proj/.workspace/MISSION.md"
out="$( cd "$SB/proj" && "$EW" 2>&1 )"
[ -z "$out" ] && ok "inline comment stripped: a commented pointer to a REAL spec stays silent" \
  || no "commented pointer to a real spec still warned: $out"

printf -- '---\nstate: building\nspec: specs/gone.md   # picked in session 3\n---\n' >"$SB/proj/.workspace/MISSION.md"
out="$( cd "$SB/proj" && "$EW" 2>&1 )"
echo "$out" | grep -q 'does not exist here: specs/gone.md$' \
  && ok "commented pointer to a MISSING spec still warns, with the clean path" \
  || no "missing-spec warning absent or carries the comment: $out"

printf 'MINE\n' >"$SB/proj/.workspace/MISSION.md"
before="$(cat "$SB/proj/.workspace/MISSION.md")"
n=0; while [ $n -lt 10 ]; do ( cd "$SB/proj" && "$EW" >/dev/null 2>&1 ); n=$((n+1)); done
is "idempotent across ten runs — MISSION.md untouched" "$(cat "$SB/proj/.workspace/MISSION.md")" "$before"

printf -- '---\nstate\nnot: yaml: at all\n---\n' >"$SB/proj/.workspace/MISSION.md"
out="$( cd "$SB/proj" && "$EW" 2>&1 )"; rc=$?
is "malformed frontmatter still exits 0" "$rc" 0
echo "$out" | grep -qi 'scoping' && ok "reports the default textually instead of repairing" || no "did not report the default"
grep -q 'not: yaml: at all' "$SB/proj/.workspace/MISSION.md" && ok "malformed file left as-is" || no "malformed file was rewritten"

printf -- '---\nstate: building\nspec: specs/nope.md\n---\n' >"$SB/proj/.workspace/MISSION.md"
out="$( cd "$SB/proj" && "$EW" 2>&1 )"
echo "$out" | grep -q 'specs/nope.md' && ok "reports an absent spec path" || no "did not report the absent spec"
grep -q 'specs/nope.md' "$SB/proj/.workspace/MISSION.md" && ok "never repairs the spec pointer" || no "spec pointer was rewritten"

out="$( cd "$SB" && "$EW" 2>&1 )"; rc=$?
is "outside a git repo: exits 0" "$rc" 0
[ -e "$SB/.workspace" ] && no "created .workspace/ outside a repo" || ok "no-op outside a git repo"

wt() { ( cd "$SB/proj" && "$WT" "$@" ); }   # never let wt resolve a repo outside the sandbox

echo "wt — happy path"
wt --branch feat/thing >"$SB/o" 2>&1; is "exits 0" "$?" 0
[ -d "$SB/worktrees/thing" ] && ok "slashed branch lands at the last path segment" || no "wrong directory: $(cat "$SB/o")"
is "branch is the full name" "$(git -C "$SB/worktrees/thing" rev-parse --abbrev-ref HEAD 2>/dev/null)" "feat/thing"
[ -f "$SB/worktrees/thing/.workspace/MISSION.md" ] && ok ".workspace/ created" || no ".workspace/ missing"
[ -f "$SB/worktrees/thing/setup.log" ] && ok "make setup ran" || no "make setup did not run"
is "branched from origin/main" \
  "$(git -C "$SB/worktrees/thing" rev-parse HEAD)" "$(git -C "$SB/proj" rev-parse origin/main)"

echo "wt — resolves a project through the registry"
cat >"$XDG_CONFIG_HOME/agents/projects.yaml" <<YAML
projects:
  demo:
    repo: $SB/proj
    worktree_root: $SB/registry-root
YAML
wt demo --branch viaregistry >"$SB/o" 2>&1; is "exits 0" "$?" 0
[ -d "$SB/registry-root/viaregistry" ] && ok "used the registry's worktree_root" || no "ignored worktree_root"
# Scoped to this test: while it exists, every later wt call would resolve here by repo path
# rather than falling back to <container>/worktrees.
rm -f "$XDG_CONFIG_HOME/agents/projects.yaml"

echo "workspace-record (T0.9) — atomic, never overwrites"
WR="$REPO/bin/workspace-record"
( cd "$SB/proj" && for i in $(seq 40); do "$WR" handoff race >/dev/null 2>&1 & done; wait )
made=$(ls "$SB/proj/.workspace/history" 2>/dev/null | grep -c 'handoff-race')
is "40 concurrent writers in the same second all survive" "$made" 40
dupes=$(ls "$SB/proj/.workspace/history" | grep 'handoff-race' | sort | uniq -d | wc -l | tr -d ' ')
is "no two writers got the same name" "$dupes" 0
( cd "$SB/proj" && a=$("$WR" artifact ev.log) && echo DATA >"$a" && "$WR" artifact ev.log >/dev/null )
is "artifacts are write-once — the original is intact" "$(cat "$SB/proj/.workspace/artifacts/ev.log")" "DATA"
[ -f "$SB/proj/.workspace/artifacts/ev-2.log" ] && ok "the second artifact request got a new name" || no "no -2 artifact"
( cd "$SB/proj" && "$WR" handoff 'a/b' >/dev/null 2>&1 ); is "refuses a slug with a slash" "$?" 1
( cd "$SB" && "$WR" handoff x >/dev/null 2>&1 ); is "refuses outside a git repo" "$?" 1

echo "ensure-workspace.sh — concurrent creation cannot clobber (the noclobber path)"
# The -e check covers every non-concurrent case, so nothing exercised O_EXCL. Race N writers at a
# genuinely empty worktree: exactly one must win and the file must never be truncated by a loser.
rc_ok=1
for attempt in 1 2 3; do
  rm -rf "$SB/proj/.workspace"
  for i in $(seq 1 25); do ( cd "$SB/proj" && "$EW" >/dev/null 2>&1 ) & done; wait
  n=$(ls "$SB/proj/.workspace"/MISSION.md 2>/dev/null | wc -l | tr -d ' ')
  body=$(grep -c '^state: scoping' "$SB/proj/.workspace/MISSION.md" 2>/dev/null || echo 0)
  head=$(head -1 "$SB/proj/.workspace/MISSION.md" 2>/dev/null)
  [ "$n" = "1" ] && [ "$body" = "1" ] && [ "$head" = "---" ] || rc_ok=0
done
# NOTE: this proves the OUTCOME (one intact file), not the noclobber mechanism. Every writer
# emits identical bytes, so a clobber reproduces the same file and is indistinguishable here.
# DECISION J's atomicity requirement that carries real risk is history/ and artifacts/, where
# writers produce DIFFERENT content — that is covered by the 40-writer test above.
[ "$rc_ok" = "1" ] && ok "25 racing writers x3 rounds leave exactly one intact MISSION.md" \
  || no "a concurrent create produced a missing or truncated MISSION.md"

echo "registry migration (T0.8) — and wt reads the result"
cat >"$SB/depot-registry.yaml" <<YAML
# a comment that must survive
profiles:
  claude:
    launch: claude {prompt}

projects:
  demo:
    repo: $SB/proj
    worktree_root: $SB/old-root   # inline comment
YAML
src_before="$(shasum -a 256 "$SB/depot-registry.yaml" | cut -d' ' -f1)"
"$REPO/install/migrate-registry.py" "$SB/depot-registry.yaml" "$SB/config/agents/projects.yaml" >/dev/null 2>&1
is "source registry untouched" "$(shasum -a 256 "$SB/depot-registry.yaml" | cut -d' ' -f1)" "$src_before"
grep -q 'a comment that must survive' "$SB/config/agents/projects.yaml" && ok "comments preserved" || no "comments lost"
grep -q 'inline comment' "$SB/config/agents/projects.yaml" && ok "inline comments preserved" || no "inline comments lost"
grep -q '^  depot:' "$SB/config/agents/projects.yaml" && ok "the depot project is added" || no "depot not added"
python3 -c "import yaml,sys; d=yaml.safe_load(open('$SB/config/agents/projects.yaml')); assert d['profiles']['claude']; assert d['projects']['depot']" \
  && ok "migrated file parses as YAML with profiles intact" || no "migrated file does not parse"
wt demo --branch frommigrated >"$SB/o" 2>&1; is "wt resolves a project from the MIGRATED file" "$?" 0
[ -d "$SB/old-root/frommigrated" ] && ok "wt honoured its worktree_root" || no "wt ignored worktree_root"
"$REPO/install/migrate-registry.py" "$SB/depot-registry.yaml" "$SB/config/agents/projects.yaml" >"$SB/o" 2>&1
grep -q 'left untouched' "$SB/o" && ok "never overwrites an existing target" || no "overwrote the target"
rm -f "$SB/config/agents/projects.yaml"

echo "registry migration — the transform refuses a shape it cannot safely edit"
# It used to append the new project at EOF, which only landed inside projects: because projects:
# happened to be the last top-level key. And current_repo was never reset, so a project missing
# repo: would inherit the previous one's and rewrite the WRONG entry.
# A repo path deliberately OUTSIDE WORKTREE_ROOTS: this case tests where the depot block lands,
# not the rewrite. A mapped path here would look like a partial match and trip the moved-registry
# guard, testing that instead.
printf 'projects:\n  fixture:\n    repo: /tmp/fixture-repo\n    worktree_root: /tmp/old\nprofiles:\n  claude:\n    launch: c\n' >"$SB/notlast.yaml"
"$REPO/install/migrate-registry.py" "$SB/notlast.yaml" "$SB/notlast.out" >/dev/null 2>&1
python3 - "$SB/notlast.out" <<'PY' && ok "depot lands INSIDE projects: even when projects: is not last" || no "depot landed under the wrong key"
import yaml,sys
d=yaml.safe_load(open(sys.argv[1]))
assert "depot" in d["projects"], d["projects"]
assert "claude" in d["profiles"], d
PY
printf 'projects:\n  a:\n    worktree_root: ~/x\n' >"$SB/norepo.yaml"
"$REPO/install/migrate-registry.py" "$SB/norepo.yaml" "$SB/norepo.out" >"$SB/o" 2>&1
is "refuses a worktree_root with no preceding repo:" "$?" 1
[ -e "$SB/norepo.out" ] && no "wrote output despite refusing" || ok "and writes nothing when it refuses"
echo "registry migration — no project is silently left behind"
# A project with no WORKTREE_ROOTS entry keeps its old root. Absent from the output, that is
# indistinguishable from "correct" in the diff Wave 1 reads before activating the registry.
"$REPO/install/migrate-registry.py" "$SB/notlast.yaml" "$SB/disp.out" >"$SB/o" 2>&1
grep -q 'NO MAPPING' "$SB/o" && ok "an unmapped project's disposition is reported" \
  || no "an unmapped project was left silent: $(cat "$SB/o")"
# Partial match = the registry moved out from under the map; migrating anyway strands a project.
cat >"$SB/moved.yaml" <<YAML
projects:
  a:
    repo: ~/smoke/code/smoke-screen
    worktree_root: ~/workspaces/smoke-screen
  b:
    repo: ~/melting/code/RENAMED
    worktree_root: ~/workspaces/melting-v1
YAML
"$REPO/install/migrate-registry.py" "$SB/moved.yaml" "$SB/moved.out" >"$SB/o" 2>&1
is "refuses when only SOME mapped repos are present" "$?" 1
grep -q 'the registry moved' "$SB/o" && ok "says the registry moved" || no "wrong reason"
[ -e "$SB/moved.out" ] && no "wrote output despite refusing" || ok "and wrote nothing"

printf 'profiles:\n  claude:\n    launch: c\n' >"$SB/noproj.yaml"
"$REPO/install/migrate-registry.py" "$SB/noproj.yaml" "$SB/noproj.out" >"$SB/o" 2>&1
is "refuses a registry with no projects: key" "$?" 1
# Assert the MESSAGE too: exit-code-only passes identically when the script crashes, so a broken
# guard that raises TypeError instead of refusing cleanly would read as a pass.
{ grep -q "^migrate-registry: no top-level 'projects:' key" "$SB/o" && ! grep -q 'Traceback' "$SB/o"; } \
  && ok "refuses cleanly — a crash would repeat the message but add a traceback" \
  || no "exited non-zero for the wrong reason: $(head -2 "$SB/o")"

echo "wt — refusals"
# The branch and path refusals must be tested SEPARATELY. Reusing feat/thing tests both at once:
# with the branch check disabled the path check fires, produces the same exit 1, and the
# assertion cannot tell which rule ran — so a broken branch refusal reads as a pass.
git -C "$SB/proj" branch -q lonelybranch 2>/dev/null
wt --branch lonelybranch >"$SB/o" 2>&1; is "an existing branch refuses even when its path is free" "$?" 1
grep -q "^wt: branch '.*' already exists" "$SB/o" && ok "wt's OWN refusal fired, not git's failure" \
  || no "refused for the wrong reason: $(head -1 "$SB/o")"
[ -e "$SB/worktrees/lonelybranch" ] && no "created a worktree despite refusing" || ok "and created nothing"

wt --branch feat/thing >"$SB/o" 2>&1; is "existing branch refuses" "$?" 1
grep -q "$SB/worktrees/thing" "$SB/o" && ok "prints the existing path" || no "did not print the path"

for bad in '-rf' 'a..b' 'has space'; do
  wt --branch "$bad" >"$SB/o" 2>&1
  is "refuses an invalid branch name: '$bad'" "$?" 1
  grep -q 'invalid branch name\|unknown option' "$SB/o" && ok "  says why" || no "  wrong reason: $(cat "$SB/o")"
done

mkdir -p "$SB/worktrees/taken"
wt --branch taken >"$SB/o" 2>&1; is "existing directory refuses" "$?" 1
grep -q 'path already exists' "$SB/o" && ok "says the path exists" || no "wrong reason"

wt --branch x --base other >"$SB/o" 2>&1; is "--base refuses" "$?" 1
grep -q 'no --base' "$SB/o" && ok "explains that origin/main is absolute" || no "wrong reason"

( cd "$SB" && "$WT" --branch nope >"$SB/o" 2>&1 ); is "outside a repo with no project refuses" "$?" 1
grep -q 'not inside a git repository' "$SB/o" && ok "says why" || no "wrong reason"

wt no-such-project --branch x >"$SB/o" 2>&1; is "unknown project refuses" "$?" 1
grep -q "no project 'no-such-project'" "$SB/o" && ok "names the missing project" || no "wrong reason"

git clone -q "$SB/origin" "$SB/noremote" 2>/dev/null
git -C "$SB/noremote" remote remove origin
( cd "$SB/noremote" && "$WT" --branch x >"$SB/o" 2>&1 ); is "no origin refuses" "$?" 1
grep -q "no 'origin' remote" "$SB/o" && ok "says why" || no "wrong reason"

echo "wt — setup handling"
wt --branch nosetup --no-setup >"$SB/o" 2>&1; is "--no-setup exits 0" "$?" 0
[ -f "$SB/worktrees/nosetup/setup.log" ] && no "--no-setup still ran setup" || ok "--no-setup skipped it"

git -C "$SB/proj" rm -q Makefile && git -C "$SB/proj" commit -qm "drop makefile" && git -C "$SB/proj" push -q origin main
wt --branch nomake >"$SB/o" 2>&1; is "no Makefile exits 0" "$?" 0
grep -q 'no Makefile' "$SB/o" && ok "says it skipped setup" || no "skipped silently without saying so"

printf 'setup:\n\t@exit 3\n' >"$SB/proj/Makefile"
git -C "$SB/proj" add -A && git -C "$SB/proj" commit -qm "failing setup" && git -C "$SB/proj" push -q origin main
wt --branch badsetup >"$SB/o" 2>&1; is "failing setup exits non-zero" "$?" 1
[ -d "$SB/worktrees/badsetup" ] && ok "the worktree is KEPT on setup failure" || no "worktree was rolled back"
grep -q 'kept' "$SB/o" && ok "says the worktree was kept" || no "did not say so"
[ -f "$SB/worktrees/badsetup/.workspace/MISSION.md" ] && ok ".workspace/ survives a setup failure" || no ".workspace/ missing"

echo "wt — run from INSIDE a worktree (the normal case: code/ is only a reference checkout)"
# --show-toplevel returns the CURRENT worktree, so resolving the repo that way nests
# worktrees/worktrees/ and makes the registry lookup miss. wt must find the MAIN checkout.
printf 'setup:\n\t@echo ok >setup.log\n' >"$SB/proj/Makefile"
git -C "$SB/proj" add -A && git -C "$SB/proj" commit -qm "restore setup" && git -C "$SB/proj" push -q origin main
( cd "$SB/worktrees/thing" && "$WT" --branch fromworktree >"$SB/o" 2>&1 )
is "wt run from inside a worktree exits 0" "$?" 0
[ -d "$SB/worktrees/fromworktree" ] && ok "it lands beside its siblings, not nested" \
  || no "landed elsewhere: $(grep -o '/.*' "$SB/o" | tail -1)"
[ -d "$SB/worktrees/worktrees" ] && no "created a nested worktrees/worktrees/" || ok "no nested worktrees/worktrees/"
[ -f "$SB/worktrees/fromworktree/.workspace/MISSION.md" ] && ok "and it still got .workspace/" || no ".workspace/ missing"

echo "wt — a RELATIVE worktree_root cannot half-create a worktree"
# git -C resolves a relative path against the repo; every later check resolves it against the
# caller's cwd. Unabsolutised, the worktree lands where nothing else looks and wt reports success
# having silently skipped both .workspace/ and setup.
mkdir -p "$SB/config/agents"
cat >"$SB/config/agents/projects.yaml" <<YAML
projects:
  rel:
    repo: $SB/proj
    worktree_root: relroot
YAML
( cd "$SB" && "$WT" rel --branch relbranch >"$SB/o" 2>&1 )
is "a relative worktree_root still exits 0" "$?" 0
[ -f "$SB/relroot/relbranch/.workspace/MISSION.md" ] && ok "resolved against the caller's cwd, and .workspace/ was created" \
  || no "half-created: $(cat "$SB/o")"
[ -d "$SB/proj/relroot" ] && no "the worktree landed INSIDE the main checkout" || ok "nothing nested inside the main checkout"
rm -f "$SB/config/agents/projects.yaml"

echo "wt — unadopted repo"
[ -d "$SB/worktrees/thing/.claude" ] && no "the disposable repo was adopted" || ok "repo is unadopted"

echo ".workspace/ never enters git"
git -C "$SB/proj" status --porcelain --untracked-files=all 2>/dev/null | grep -q '.workspace' \
  && no ".workspace/ is visible to git" || ok ".workspace/ is ignored, so no worktree inherits another's memory"
git -C "$SB/proj" ls-files 2>/dev/null | grep -q '.workspace' && no ".workspace/ got committed" || ok ".workspace/ is not tracked"

echo "spec-session-orient.sh (T0.10) — read-only orientation"
OR="$REPO/adopt/hooks/spec-session-orient.sh"
fresh="$SB/worktrees/orient"
wt --branch orient >/dev/null 2>&1

# Registration order is load-bearing, so verify in a BRAND-NEW worktree, not an existing one:
# run the two hooks in the order SessionStart registers them and confirm orientation sees what
# the initialiser just created.
snap_before="$(cd "$fresh" && find . -path ./.git -prune -o -type f -print | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)"
( cd "$fresh" && "$EW" >/dev/null 2>&1 )
out="$( cd "$fresh" && "$OR" 2>/dev/null )"
snap_after="$(cd "$fresh" && find . -path ./.git -prune -o -type f -print | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)"
echo "$out" | grep -q 'scoping' && ok "fresh worktree: orients off what ensure-workspace created" || no "orientation saw nothing in a fresh worktree"
is "the hook writes NOTHING" "$snap_after" "$snap_before"
[ -e "$fresh/.claude/active-spec" ] && no "still self-binds .claude/active-spec" || ok "no self-bind pointer written"
[ -e "$fresh/specs/.context" ] && no "still creates a scratch notepad" || ok "no scratch notepad written"

# Reversed order is exactly what CONTRACT §7 warns about.
wt --branch orient2 >/dev/null 2>&1
rm -rf "$SB/worktrees/orient2/.workspace"
out2="$( cd "$SB/worktrees/orient2" && "$OR" 2>/dev/null )"
[ -z "$out2" ] && ok "silent when nothing resolves (orientation before init)" || no "spoke with no workspace: $out2"

printf -- '---\nstate: building\nspec: specs/real.md\n---\n\n## Next action\n\nWire the thing up.\n' >"$fresh/.workspace/MISSION.md"
mkdir -p "$fresh/specs" && echo x >"$fresh/specs/real.md"
( cd "$fresh" && "$REPO/bin/workspace-record" handoff earlier >/dev/null && "$REPO/bin/workspace-record" handoff later >/dev/null )
( cd "$fresh" && "$REPO/bin/workspace-record" finding apidump >/dev/null )
echo "SECRET-BODY-TEXT" >"$fresh/.workspace/history/"*handoff-later*
out3="$( cd "$fresh" && "$OR" 2>/dev/null )"
echo "$out3" | grep -q 'specs/real.md'        && ok "reports the spec path"        || no "no spec path"
echo "$out3" | grep -q 'Wire the thing up'    && ok "reports the next action"      || no "no next action"
echo "$out3" | grep -q 'handoff-later'        && ok "reports the NEWEST handoff"   || no "wrong/no handoff"
echo "$out3" | grep -q 'handoff-earlier'      && no "reported an older handoff too" || ok "only the newest handoff"
echo "$out3" | grep -q 'finding-apidump'      && ok "reports finding filenames"    || no "no findings"
echo "$out3" | grep -q 'SECRET-BODY-TEXT'     && no "leaked record CONTENTS into context" || ok "filenames only, never contents"

printf -- '---\nstate: building\nspec: specs/gone.md\n---\n' >"$fresh/.workspace/MISSION.md"
out4="$( cd "$fresh" && "$OR" 2>/dev/null )"
echo "$out4" | grep -q 'does not exist' && ok "reports an absent spec without repairing it" || no "did not report absent spec"
grep -q 'specs/gone.md' "$fresh/.workspace/MISSION.md" && ok "left the mission untouched" || no "rewrote the mission"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
