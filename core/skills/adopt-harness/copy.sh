#!/usr/bin/env bash
# copy.sh — the MECHANICAL half of adopting this harness into a target repo.
#
# The MANIFEST below IS the definition of what travels. The adopt-harness SKILL drives this
# (copy → scout the target → draft the fills → verify); standalone it just does the copy and
# prints the fill checklist.
#
# Usage:  copy.sh <target-repo-path> [python|ts|none]
#   arg2 = which gate.example to install as the repo's make/gate.mk (default: none).
#         copy.sh --check <target-repo-path>
#   reports how far behind this harness the repo's adoption is (decision O).
#   exit 0 = up to date · 1 = behind · 2 = cannot tell (no stamp, unknown commit)
#
# Re-runnable: never clobbers filled-in work. Anything a repo edits after adoption —
# CLAUDE.md, AGENTS.md, make/gate.mk, .claude/settings.json, .codex/hooks.json — is written
# only when absent, and skipped with a notice otherwise. Re-running IS the supported upgrade
# path (decision O): scaffolding refreshes, fills survive, and the version stamp updates.
#
# Two providers, one repo. Claude reads .claude/; Codex reads AGENTS.md and .agents/skills.
# The hook SCRIPTS are shared — one copy at .claude/hooks/, bound twice.
set -euo pipefail

CHECK=0
if [ "${1:-}" = "--check" ]; then CHECK=1; shift; fi
TARGET="${1:-}"
GATE_FLAVOR="${2:-none}"
[ -z "$TARGET" ] && { echo "usage: copy.sh [--check] <target-repo-path> [python|ts|none]" >&2; exit 1; }
[ -d "$TARGET" ] || { echo "✗ target is not a directory: $TARGET" >&2; exit 1; }
TARGET="$(cd "$TARGET" && pwd)"

# Harness root = four levels up from core/skills/adopt-harness/.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
[ "$ROOT" = "$TARGET" ] && { echo "✗ refusing to adopt a repo into itself" >&2; exit 1; }
[ -d "$ROOT/adopt" ] || { echo "✗ no adopt/ payload at $ROOT/adopt" >&2; exit 1; }

note() { printf '  %s\n' "$*"; }

STAMP_REL=".claude/harness-version"

# ── Decision O's check: the stamp against THIS harness clone, measured by git, never guessed.
if [ "$CHECK" -eq 1 ]; then
  name="$(basename "$TARGET")"
  [ -f "$TARGET/$STAMP_REL" ] || { echo "✗ $name has no $STAMP_REL — never adopted, or adopted before stamping existed. Re-run copy.sh to stamp it." >&2; exit 2; }
  stamp="$(head -1 "$TARGET/$STAMP_REL")"
  git -C "$ROOT" rev-parse HEAD >/dev/null 2>&1 || { echo "✗ this harness copy is not a git checkout — nothing to compare against" >&2; exit 2; }
  git -C "$ROOT" cat-file -e "$stamp^{commit}" 2>/dev/null \
    || { echo "✗ stamp $stamp is not in this harness clone's history — fetch, or the repo was adopted from a different harness" >&2; exit 2; }
  ahead="$(git -C "$ROOT" rev-list --count "HEAD..$stamp")"
  if [ "$ahead" -gt 0 ]; then
    echo "? $name was adopted from a commit $ahead ahead of this clone — pull this clone first" >&2; exit 2
  fi
  behind="$(git -C "$ROOT" rev-list --count "$stamp..HEAD")"
  if [ "$behind" -eq 0 ]; then
    echo "✓ $name is up to date with this harness ($(git -C "$ROOT" rev-parse --short HEAD))"; exit 0
  fi
  echo "⚠ $name is $behind commit(s) behind this harness (adopted at $(git -C "$ROOT" rev-parse --short "$stamp"), harness at $(git -C "$ROOT" rev-parse --short HEAD))"
  echo "  re-running adoption is the supported upgrade path:  copy.sh $TARGET"
  exit 1
fi

# ── Copied unconditionally: scaffolding a repo never hand-edits. src → dest.
FIXED=(
  "adopt/Makefile:Makefile"
  "adopt/make/gate.example-python.mk:make/gate.example-python.mk"
  "adopt/make/gate.example-ts.mk:make/gate.example-ts.mk"
  "adopt/hooks:.claude/hooks"
  "adopt/specs:specs"
)

# ── Written only when absent: a repo fills these in and re-adoption must not undo that.
ONCE=(
  "adopt/CLAUDE.template.md:CLAUDE.md"
  "adopt/AGENTS.template.md:AGENTS.md"
  "adopt/settings.json:.claude/settings.json"
  "adopt/codex/hooks.json:.codex/hooks.json"
  "adopt/docs/INDEX.md:docs/INDEX.md"
  "adopt/docs/architecture.md:docs/architecture.md"
  "adopt/docs/glossary.md:docs/glossary.md"
  "adopt/docs/adrs/README.md:docs/adrs/README.md"
  "adopt/docs/adrs/0000-template.md:docs/adrs/0000-template.md"
)

echo "→ adopting harness from $ROOT into $TARGET"

for pair in "${FIXED[@]}"; do
  src="$ROOT/${pair%%:*}"; dst="$TARGET/${pair#*:}"
  [ -e "$src" ] || { note "⚠ missing in base, skipped: ${pair%%:*}"; continue; }
  mkdir -p "$(dirname "$dst")"
  if [ -d "$src" ]; then
    mkdir -p "$dst"
    (cd "$src" && tar cf - .) | (cd "$dst" && tar xf -)
  else
    cp -p "$src" "$dst"
  fi
  note "→ ${pair#*:}"
done

for pair in "${ONCE[@]}"; do
  src="$ROOT/${pair%%:*}"; dst="$TARGET/${pair#*:}"
  [ -e "$src" ] || { note "⚠ missing in base, skipped: ${pair%%:*}"; continue; }
  if [ -e "$dst" ]; then
    note "⚠ ${pair#*:} already exists — left it"
  else
    mkdir -p "$(dirname "$dst")"
    cp -p "$src" "$dst"
    note "→ ${pair#*:}"
  fi
done

chmod +x "$TARGET"/.claude/hooks/*.sh 2>/dev/null || true

# ── Decision O: hook scripts are copied per repo (decision K), so a fix reaches a repo only by
# re-adoption — the stamp is what lets a check say "this repo is N commits behind". Refreshed on
# every run; fails open when the harness copy has no git history to record.
if src_sha="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null)"; then
  mkdir -p "$TARGET/.claude"
  {
    printf '%s\n' "$src_sha"
    printf '# harness source commit at adoption — written by adopt-harness/copy.sh (decision O)\n'
    printf '# staleness: run  copy.sh --check <this-repo>  from a harness clone\n'
    git -C "$ROOT" diff --quiet HEAD 2>/dev/null || printf '# the harness working tree was DIRTY at adoption; the stamp understates it\n'
  } >"$TARGET/$STAMP_REL"
  note "→ $STAMP_REL ($(git -C "$ROOT" rev-parse --short HEAD))"
else
  note "⚠ harness copy has no git history — no version stamp written"
fi

# ── Codex discovers PROJECT skills through .agents/skills. One directory, both providers.
mkdir -p "$TARGET/.claude/skills"
if [ -L "$TARGET/.agents/skills" ]; then
  note "→ .agents/skills → .claude/skills (already linked)"
elif [ -e "$TARGET/.agents/skills" ]; then
  note "⚠ .agents/skills exists and is not a symlink — left it"
else
  mkdir -p "$TARGET/.agents"
  ln -s ../.claude/skills "$TARGET/.agents/skills"
  note "→ .agents/skills → .claude/skills"
fi

# ── Gate overlay (Slot 2).
if [ "$GATE_FLAVOR" != "none" ]; then
  ex="$TARGET/make/gate.example-$GATE_FLAVOR.mk"
  if [ ! -e "$ex" ]; then
    note "⚠ no gate example for '$GATE_FLAVOR' — skipping gate.mk install"
  elif [ -e "$TARGET/make/gate.mk" ]; then
    note "⚠ make/gate.mk already exists — left it"
  else
    cp "$ex" "$TARGET/make/gate.mk"
    note "→ make/gate.mk from the $GATE_FLAVOR example (set GATE_STEPS to real checks)"
  fi
fi

cat <<'EOF'

✅ harness copied. Now fill the slots (the adopt-harness skill does this with you):
  1. AGENTS.md    — the <FILL> lines: what/stack/structure/conventions/hotspots.
                    It is THE profile; CLAUDE.md just imports it. Do not restate it there.
  2. make/gate.mk — set GATE_STEPS to this repo's REAL checks
  3. docs/        — architecture.md + glossary.md: how THIS codebase works (start at INDEX.md)
Then: `make setup && make check` on a fresh clone → green.
EOF
