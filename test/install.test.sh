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

echo "fresh machine: a full run against an EMPTY \$HOME (PF6)"
# The sandbox above models THIS machine — it seeds a depot registry before the first run. A fresh
# or second machine has nothing: no ~/.config, no registry, no ~/.local/bin. That must be a clean
# first-class install, not an error path. Second-machine adoption is this case with real paths.
FM="$SB/fresh-home"; mkdir -p "$FM"
runF() { HOME="$FM" XDG_CONFIG_HOME="$FM/.config" "$REPO/install.sh" "$@" >"$SB/out" 2>&1; echo $?; }
is "exits 0" "$(runF)" 0
[ -f "$FM/.agents/skills/tdd/SKILL.md" ] && ok "core/ landed in the empty home" || no "core/ did not land"
[ -f "$FM/.agents/.install-manifest.sha256" ] && ok "install manifest written" || no "no install manifest"
outhas 'no registry at' && ok "absent registry reported as nothing-to-migrate, not an error" \
  || no "absent registry not handled as the normal fresh-machine case"
[ -e "$FM/.config/agents/projects.yaml" ] && no "conjured a registry from nothing" || ok "no registry invented"
[ -x "$FM/.local/bin/wt" ] && ok "wt installed into a created ~/.local/bin" || no "wt missing"
[ -x "$FM/.local/bin/ensure-workspace.sh" ] && ok "ensure-workspace.sh fallback installed" || no "fallback initialiser missing"
[ -x "$FM/.local/bin/workspace-record" ] && ok "workspace-record installed" || no "workspace-record missing"
[ -d "$FM/.agents.prev" ] && no "a first run has nothing to back up, yet made a backup" || ok "no backup on a first run"
[ -e "$FM/.agents.swap-in-progress" ] && no "swap flag left behind" || ok "no swap flag left behind"
df1="$(digest "$FM/.agents")"
is "a second run exits 0" "$(runF)" 0
is "and is idempotent — identical tree" "$(digest "$FM/.agents")" "$df1"
[ -d "$FM/.agents.prev" ] && ok "the second run made the backup" || no "no backup after the second run"

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
runR --review </dev/null >/dev/null   # decision N: --prune never runs blind
is "--prune exits 0" "$(runR --prune)" 0
[ -f "$SB/.agents/skills/leftover/SKILL.md" ] && no "not pruned" || ok "dropped with --prune"
[ -f "$SB/.agents.prev/skills/leftover/SKILL.md" ] && ok "pruned file recoverable from the backup" || no "pruned file unrecoverable"

echo "a path containing a SPACE round-trips through the manifest"
# awk '$2==p' stops at the first space, so such a path never matched its manifest entry and was
# refused as "edited" on every subsequent run — permanently, blaming an edit that never happened.
mkdir -p "$SB/repo/core/skills/my skill"; printf 'body\n' >"$SB/repo/core/skills/my skill/SKILL.md"
is "installs a space-containing path" "$(runR)" 0
grep -q 'skills/my skill/SKILL.md' "$SB/.agents/.install-manifest.sha256" \
  && ok "the manifest records the full path" || no "manifest entry truncated at the space"
# The manifest is only consulted when core/ has MOVED ON: an unchanged file matches by hash and
# never reaches installed_sha. So change the source — that is the only path that reads the parse.
printf 'upstream change\n' >>"$SB/repo/core/skills/my skill/SKILL.md"
is "an upstream change to it does not falsely refuse" "$(runR --dry-run)" 0
outhas 'update  1' && ok "classified as update — the manifest lookup matched" \
  || no "manifest lookup failed; the path was refused as a local edit"
# --prune, not a bare run: without it the now-sourceless file stays as a kept extra and every
# later "keep" assertion counts it too.
rm -rf "$SB/repo/core/skills/my skill"; runR --review </dev/null >/dev/null; runR --prune >/dev/null
[ -e "$SB/.agents/skills/my skill" ] && no "the space-path leaked into later tests" || ok "cleaned up after itself"

echo "~/.agents must be a real directory, not a symlink"
# The swap replaces the whole tree, so a symlinked $DEST is consumed and its target's files are
# silently adopted as machine-wide extras. ~/.claude is that exact shape today.
mv "$SB/.agents" "$SB/.agents-real"; mkdir -p "$SB/other"; echo mine >"$SB/other/keepme.txt"
ln -s "$SB/other" "$SB/.agents"
is "refuses a symlinked ~/.agents" "$(runR)" 1
outhas 'is a symlink to' && ok "names the link and its target" || no "did not explain why"
[ -L "$SB/.agents" ] && ok "the link is left alone" || no "the link was consumed"
[ -f "$SB/other/keepme.txt" ] && ok "the link's target is untouched" || no "target files were disturbed"
is "--dry-run refuses it too" "$(runR --dry-run)" 1
rm -f "$SB/.agents"; mv "$SB/.agents-real" "$SB/.agents"

echo "a SYMLINK in the tree gets the same promise as a regular file"
# It used to get none: -type f made it invisible to the whole plan, so the swap silently ate it
# and "nothing is dropped without --prune" quietly did not apply.
ln -s skills/tdd "$SB/.agents/shortcut"
# Match the NAME under "keep", not a count — a count couples this to whatever earlier tests left.
runR --dry-run >/dev/null; outhas '^ *shortcut$' && ok "a symlink is counted, not invisible" || no "symlink missing from the plan"
is "exits 0" "$(runR)" 0
[ -L "$SB/.agents/shortcut" ] && ok "the symlink survives an install" || no "the symlink was silently eaten"
[ "$(readlink "$SB/.agents/shortcut")" = "skills/tdd" ] && ok "and is still a link, not a copy of its target" \
  || no "the link was dereferenced into a regular file"
runR --review </dev/null >/dev/null   # decision N: --prune never runs blind
is "--prune exits 0" "$(runR --prune)" 0
[ -e "$SB/.agents/shortcut" ] && no "symlink not pruned" || ok "and --prune still drops it on request"

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

echo "--review (decision N) — the inbox, and --prune never runs blind"
# Answers ride stdin: the inbox walks drift (sorted) then extras (sorted), one read per item;
# EOF means leave. Every case below keeps the inbox to a single item so the answer is unambiguous.
rm -f "$SB/.agents.reviewed"
mkdir -p "$SB/.agents/skills/novel"; printf 'novel machine skill\n' >"$SB/.agents/skills/novel/SKILL.md"
is "a blind --prune refuses" "$(runR --prune)" 1
outhas 'never runs blind' && ok "and says why" || no "no explanation"
[ -f "$SB/.agents/skills/novel/SKILL.md" ] && ok "the refusal deleted nothing" || no "the refusal still deleted"
is "--review --prune is refused as a combination" "$(runR --review --prune)" 2
is "--review --dry-run likewise" "$(runR --review --dry-run)" 2

dA="$(digest "$SB/.agents")"; dRepo="$(digest "$SB/repo/core")"
is "--review with no answers (EOF = leave) exits 0" "$(runR --review </dev/null)" 0
is "and wrote nothing to ~/.agents/" "$(digest "$SB/.agents")" "$dA"
is "and nothing to the repo" "$(digest "$SB/repo/core")" "$dRepo"
[ -f "$SB/.agents.reviewed" ] && ok "the review was recorded" || no "no review stamp"
is "a reviewed --prune proceeds" "$(runR --prune)" 0
[ -e "$SB/.agents/skills/novel" ] && no "the reviewed extra survived --prune" || ok "the reviewed extra was dropped"

echo "--review — a stale review does not authorize a prune"
mkdir -p "$SB/.agents/skills/seen"; echo s >"$SB/.agents/skills/seen/SKILL.md"
runR --review </dev/null >/dev/null
mkdir -p "$SB/.agents/skills/unseen"; echo u >"$SB/.agents/skills/unseen/SKILL.md"
is "an extra that appeared AFTER the review refuses --prune" "$(runR --prune)" 1
outhas 'changed since the last review' && ok "and says the review is stale" || no "no staleness explanation"
printf 'rewritten\n' >"$SB/.agents/skills/seen/SKILL.md"; rm -rf "$SB/.agents/skills/unseen"
is "an extra REWRITTEN after the review also refuses" "$(runR --prune)" 1
runR --review </dev/null >/dev/null; runR --prune >/dev/null   # clean up for the next cases
is "one review authorizes ONE prune — the stamp is consumed" "$( [ -f "$SB/.agents.reviewed" ] && echo kept || echo consumed )" "consumed"

echo "--review — the import disposition"
mkdir -p "$SB/.agents/skills/keeper"; printf 'worth keeping\n' >"$SB/.agents/skills/keeper/SKILL.md"
is "'i' on an extra exits 0" "$(printf 'i\n' | runR --review)" 0
grep -q 'worth keeping' "$SB/repo/core/skills/keeper/SKILL.md" 2>/dev/null \
  && ok "the machine copy entered the repo working tree" || no "no import into core/"
[ -f "$SB/.agents/skills/keeper/SKILL.md" ] && ok "the machine copy stays until an install" || no "the machine copy vanished"
runR --dry-run >/dev/null
outhas 'keeper' && no "still an extra after import" || ok "no longer an extra — core/ now provides it"

printf '\nmachine-side fix\n' >>"$SB/.agents/skills/tdd/SKILL.md"
is "'i' on a DRIFTED file exits 0" "$(printf 'i\n' | runR --review)" 0
grep -q 'machine-side fix' "$SB/repo/core/skills/tdd/SKILL.md" && ok "the machine edit entered core/" || no "the edit did not enter core/"
is "and the next run no longer refuses" "$(runR --dry-run)" 0

echo "--review — the prune disposition"
mkdir -p "$SB/.agents/skills/junk"; echo j >"$SB/.agents/skills/junk/SKILL.md"
is "'p' on an extra exits 0" "$(printf 'p\n' | runR --review)" 0
[ -e "$SB/.agents/skills/junk/SKILL.md" ] && no "'p' left the extra behind" || ok "'p' deleted the extra from ~/.agents/"
printf '\nstray edit\n' >>"$SB/.agents/skills/handoff/SKILL.md"
is "'p' on a DRIFTED file exits 0" "$(printf 'p\n' | runR --review)" 0
grep -q 'stray edit' "$SB/.agents/skills/handoff/SKILL.md" && no "the machine edit survived 'p'" \
  || ok "'p' restored the file from core/ — repo wins"
is "and the next run no longer refuses" "$(runR --dry-run)" 0

echo "--review — a secret never rides the import channel"
mkdir -p "$SB/.agents/skills/oops"
printf 'token = "ghp_%s"\n' "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" >"$SB/.agents/skills/oops/SKILL.md"
is "'i' on a secret-bearing extra still exits 0" "$(printf 'i\n' | runR --review)" 0
outhas 'import refused' && ok "the import was refused, saying why" || no "no refusal"
[ -e "$SB/repo/core/skills/oops/SKILL.md" ] && no "the secret entered the repo" || ok "the secret never entered the repo"
rm -rf "$SB/.agents/skills/oops"

echo "--review — the provider-surface survey is read-only"
mkdir -p "$SB/.claude/plugins/some-plugin"; echo p >"$SB/.claude/plugins/some-plugin/plugin.json"
mkdir -p "$SB/.claude/commands"; echo c >"$SB/.claude/commands/mine.md"
ln -s "$SB/.agents/skills" "$SB/.claude/skills"
dC="$(digest "$SB/.claude")"
is "--review exits 0" "$(runR --review </dev/null)" 0
outhas 'plugins' && ok "surveys ~/.claude/plugins/" || no "plugins not surveyed"
outhas 'some-plugin' && ok "and names what sits there" || no "entries not named"
outhas 'governed' && ok "a symlink into ~/.agents/ is reported as governed" || no "the governed symlink was not classified"
is "the survey wrote nothing" "$(digest "$SB/.claude")" "$dC"
rm -rf "$SB/.claude"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
