#!/usr/bin/env bash
# copy.sh — the MECHANICAL half of adopting this harness into a target repo.
#
# The MANIFEST below IS the definition of what travels. The adopt-harness SKILL drives this
# (copy → scout the target → draft the fills → verify); standalone it just does the copy and
# prints the fill checklist.
#
# Usage:  copy.sh <target-repo-path> [python|ts|none]
#   arg2 = which gate.example to install as the repo's make/gate.mk (default: none).
#
# Re-runnable: never clobbers filled-in work. Anything a repo edits after adoption —
# CLAUDE.md, AGENTS.md, make/gate.mk, .claude/settings.json, .codex/hooks.json — is written
# only when absent, and skipped with a notice otherwise.
#
# Two providers, one repo. Claude reads .claude/; Codex reads AGENTS.md and .agents/skills.
# The hook SCRIPTS are shared — one copy at .claude/hooks/, bound twice.
set -euo pipefail

TARGET="${1:-}"
GATE_FLAVOR="${2:-none}"
[ -z "$TARGET" ] && { echo "usage: copy.sh <target-repo-path> [python|ts|none]" >&2; exit 1; }
[ -d "$TARGET" ] || { echo "✗ target is not a directory: $TARGET" >&2; exit 1; }
TARGET="$(cd "$TARGET" && pwd)"

# Harness root = four levels up from core/skills/adopt-harness/.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
[ "$ROOT" = "$TARGET" ] && { echo "✗ refusing to adopt a repo into itself" >&2; exit 1; }
[ -d "$ROOT/adopt" ] || { echo "✗ no adopt/ payload at $ROOT/adopt" >&2; exit 1; }

note() { printf '  %s\n' "$*"; }

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
  1. CLAUDE.md / AGENTS.md — the <FILL> lines: what/stack/structure/conventions/hotspots
  2. make/gate.mk          — set GATE_STEPS to this repo's REAL checks
  3. docs/                 — architecture.md + glossary.md: how THIS codebase works
Then: `make setup && make check` on a fresh clone → green.
EOF
