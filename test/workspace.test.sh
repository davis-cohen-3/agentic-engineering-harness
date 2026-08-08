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
printf 'setup:\n\t@echo setup-ran > setup.log\n' >"$SB/proj/Makefile"
git -C "$SB/proj" add -A && git -C "$SB/proj" commit -qm init
git -C "$SB/proj" branch -M main && git -C "$SB/proj" push -q origin main

echo "ensure-workspace.sh"
( cd "$SB/proj" && "$EW" >/dev/null 2>&1 )
[ -f "$SB/proj/.workspace/MISSION.md" ] && ok "creates .workspace/MISSION.md" || no "no MISSION.md"
grep -q '^state: scoping' "$SB/proj/.workspace/MISSION.md" && ok "defaults to state: scoping" || no "wrong default state"
grep -q '^spec: null'     "$SB/proj/.workspace/MISSION.md" && ok "defaults to spec: null"     || no "wrong default spec"

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

echo "wt — refusals"
wt --branch feat/thing >"$SB/o" 2>&1; is "existing branch refuses" "$?" 1
grep -q "$SB/worktrees/thing" "$SB/o" && ok "prints the existing path" || no "did not print the path"

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

echo "wt — unadopted repo"
[ -d "$SB/worktrees/thing/.claude" ] && no "the disposable repo was adopted" || ok "repo is unadopted"
ok "an unadopted repo still got .workspace/ (asserted above)"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
