#!/usr/bin/env bash
# Acceptance test for install.sh (plan/tasks.md T0.4).
#
# Everything runs against a sandbox $HOME in a temp dir, so the real machine is never touched.
# That is deliberate: T0.4's acceptance includes "a second run after reconciliation succeeds",
# which is a machine mutation Wave 1 T1.3 owns. Exercising it here proves the code path without
# taking the machine change early.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT

pass=0 fail=0
ok()   { pass=$((pass+1)); printf '  ✓ %s\n' "$1"; }
no()   { fail=$((fail+1)); printf '  ✗ %s\n' "$1"; }
is()   { [ "$2" = "$3" ] && ok "$1" || no "$1 (got '$2', want '$3')"; }

# XDG_CONFIG_HOME must be pinned as well as HOME: install.sh resolves the registry through
# ${XDG_CONFIG_HOME:-$HOME/.config}, so pinning only HOME lets a machine that sets XDG read the
# real depot registry and WRITE the real ~/.config/agents/projects.yaml — the file Wave 1 owns.
run()  { HOME="$SB" XDG_CONFIG_HOME="$SB/.config" "$REPO/install.sh" "$@" >"$SB/out" 2>&1; echo $?; }
runR() { HOME="$SB" XDG_CONFIG_HOME="$SB/.config" "$SB/repo/install.sh" "$@" >"$SB/out" 2>&1; echo $?; }
digest() { (cd "$1" && find . -type f | LC_ALL=C sort | xargs shasum -a 256 | shasum -a 256 | cut -d' ' -f1); }
outhas() { grep -q "$1" "$SB/out"; }

mkdir -p "$SB/.config/depot"
cp "$HOME/.config/depot/projects.yaml" "$SB/.config/depot/projects.yaml" 2>/dev/null \
  || printf 'projects:\n  demo:\n    repo: ~/demo\n' >"$SB/.config/depot/projects.yaml"

echo "T0.4 — install.sh"

echo "fresh install"
is "exits 0" "$(run)" 0
[ -f "$SB/.agents/skills/tdd/SKILL.md" ] && ok "core/ landed in ~/.agents/" || no "core/ did not land"
[ -f "$SB/.agents/.install-manifest.sha256" ] && ok "install manifest written" || no "no install manifest"
[ -f "$SB/.config/agents/projects.yaml" ] && ok "registry migrated into the absent target" || no "registry not migrated"

echo "idempotent"
d1="$(digest "$SB/.agents")"
is "exits 0" "$(run)" 0
is "running twice produces an identical tree" "$(digest "$SB/.agents")" "$d1"
outhas 'already present, left untouched' && ok "registry not re-migrated" || no "registry re-migrated"
[ -d "$SB/.agents.prev" ] && ok "one backup at ~/.agents.prev" || no "no backup"

echo "refuses on a hand-edited projection"
printf '\nhand edit\n' >>"$SB/.agents/skills/docs-drift/SKILL.md"
printf '\nhand edit\n' >>"$SB/.agents/skills/adopt-harness/SKILL.md"
d2="$(digest "$SB/.agents")"
is "--dry-run exits non-zero" "$(run --dry-run)" 1
outhas 'skills/docs-drift/SKILL.md'    && ok "names the first edited file"  || no "did not name docs-drift"
outhas 'skills/adopt-harness/SKILL.md' && ok "names the second edited file" || no "did not name adopt-harness"
is "--dry-run wrote nothing" "$(digest "$SB/.agents")" "$d2"
is "a real run also refuses" "$(run)" 1
is "the refused run wrote nothing" "$(digest "$SB/.agents")" "$d2"

echo "reconciled, then succeeds"
cp "$REPO/core/skills/docs-drift/SKILL.md"    "$SB/.agents/skills/docs-drift/SKILL.md"
cp "$REPO/core/skills/adopt-harness/SKILL.md" "$SB/.agents/skills/adopt-harness/SKILL.md"
is "exits 0 after reconciliation" "$(run)" 0

echo "a core/ change is an update, not a local edit"
cp -R "$REPO/core" "$SB/repo-core"; mkdir -p "$SB/repo"; cp "$REPO/install.sh" "$SB/repo/"; mv "$SB/repo-core" "$SB/repo/core"
printf '\nupstream change\n' >>"$SB/repo/core/skills/tdd/SKILL.md"
is "exits 0" "$(runR)" 0
outhas 'update  1' && ok "classified as update" || no "not classified as update"
grep -q 'upstream change' "$SB/.agents/skills/tdd/SKILL.md" && ok "the change was applied" || no "change not applied"

echo "extras: kept by default, dropped with --prune"
mkdir -p "$SB/.agents/skills/leftover"; echo x >"$SB/.agents/skills/leftover/SKILL.md"
is "exits 0" "$(runR)" 0
[ -f "$SB/.agents/skills/leftover/SKILL.md" ] && ok "kept without --prune" || no "dropped without --prune"
is "--prune exits 0" "$(runR --prune)" 0
[ -f "$SB/.agents/skills/leftover/SKILL.md" ] && no "not pruned" || ok "dropped with --prune"
[ -f "$SB/.agents.prev/skills/leftover/SKILL.md" ] && ok "pruned file recoverable from the backup" || no "pruned file unrecoverable"

echo "--force overrides, and the backup keeps the lost edit"
printf '\nlost edit\n' >>"$SB/.agents/skills/handoff/SKILL.md"
is "refuses without --force" "$(runR)" 1
is "--force exits 0" "$(runR --force)" 0
grep -q 'lost edit' "$SB/.agents/skills/handoff/SKILL.md" && no "--force did not overwrite" || ok "--force overwrote the edit"
grep -q 'lost edit' "$SB/.agents.prev/skills/handoff/SKILL.md" && ok "the lost edit is in the backup" || no "the lost edit is unrecoverable"

echo "interrupted mid-swap"
touch "$SB/.agents.swap-in-progress"; rm -rf "$SB/.agents.prev"; mv "$SB/.agents" "$SB/.agents.prev"
is "refuses with no ~/.agents present" "$(runR)" 1
outhas 'recover with' && ok "prints the recovery command" || no "no recovery instruction"
mv "$SB/.agents.prev" "$SB/.agents"
is "recovers once the tree is back" "$(runR)" 0
[ -e "$SB/.agents.swap-in-progress" ] && no "swap flag not cleared" || ok "swap flag cleared"

echo "a secret can never enter ~/.agents/"
mkdir -p "$SB/.agents/skills/leaky"
printf 'token = "ghp_%s"\n' "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" >"$SB/.agents/skills/leaky/SKILL.md"
is "refuses to stage a secret-bearing file" "$(runR)" 1
outhas 'looks like a secret' && ok "says why" || no "no explanation"
rm -rf "$SB/.agents/skills/leaky"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
