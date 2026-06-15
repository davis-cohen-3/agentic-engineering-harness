#!/usr/bin/env bash
# copy.sh — the MECHANICAL half of adopting this harness into a target repo.
#
# This file is the single source of truth for "what travels": the MANIFEST below
# IS the definition of the portable harness. The adopt-harness SKILL drives this
# (copy → then scout the target → draft the fills → verify); run standalone it
# just does the deterministic copy + prints the fill checklist.
#
# Usage:  copy.sh <target-repo-path> [python|ts|none]
#   arg2 = which gate.example to install as the repo's make/gate.mk (default: none).
#
# Idempotent-ish: never clobbers an existing CLAUDE.md or make/gate.mk in the target
# (it warns and skips), so re-running can't silently overwrite filled-in work.
set -euo pipefail

TARGET="${1:-}"
GATE_FLAVOR="${2:-none}"
[ -z "$TARGET" ] && { echo "usage: copy.sh <target-repo-path> [python|ts|none]" >&2; exit 1; }
[ -d "$TARGET" ] || { echo "✗ target is not a directory: $TARGET" >&2; exit 1; }
TARGET="$(cd "$TARGET" && pwd)"

# Harness root = three levels up from .claude/skills/adopt-harness/.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
[ "$ROOT" = "$TARGET" ] && { echo "✗ refusing to adopt a repo into itself" >&2; exit 1; }

# ── THE MANIFEST — the portable harness, exactly. Edit here when the boundary moves. ──
# Paths are relative to the harness root. Directories copy recursively. Everything
# NOT listed (docs/, README.md, harness-lab's own CLAUDE.md + make/gate.mk, .git) stays home.
MANIFEST=(
  CLAUDE.template.md          # → renamed to CLAUDE.md in the target (below)
  .claude/FLOOR.md
  .claude/settings.json
  .claude/skills            # all skills incl. VENDORED.md; adopt-harness itself pruned below
  .claude/agents
  .claude/hooks
  .claude/rules
  .claude/commands
  .mcp.json
  Makefile                  # the BASE makefile; -includes the repo's make/gate.mk
  make/gate.example-python.mk
  make/gate.example-ts.mk
  specs                     # README + template/ (scaffold the target fills)
  agent_docs                # README + architecture/glossary templates + adr/
  .gitignore
)
# The adopt tool itself must NOT travel — a repo never re-adopts. One exclusion rule.
EXCLUDE_REL=".claude/skills/adopt-harness"

echo "→ adopting harness from $ROOT into $TARGET"
for rel in "${MANIFEST[@]}"; do
  src="$ROOT/$rel"
  [ -e "$src" ] || { echo "  ⚠ missing in base, skipped: $rel"; continue; }
  mkdir -p "$TARGET/$(dirname "$rel")"
  cp -R "$src" "$TARGET/$(dirname "$rel")/"
done

# Prune the adopt tool from the copied tree.
rm -rf "${TARGET:?}/$EXCLUDE_REL"

# CLAUDE.template.md → CLAUDE.md (never clobber an existing profile).
if [ -e "$TARGET/CLAUDE.md" ]; then
  echo "  ⚠ target already has CLAUDE.md — left it; template copied as CLAUDE.template.md"
else
  mv "$TARGET/CLAUDE.template.md" "$TARGET/CLAUDE.md"
fi

# Gate overlay (Slot 2): install the chosen example as make/gate.mk (never clobber).
if [ "$GATE_FLAVOR" != "none" ]; then
  ex="$TARGET/make/gate.example-$GATE_FLAVOR.mk"
  if [ ! -e "$ex" ]; then
    echo "  ⚠ no gate example for '$GATE_FLAVOR' — skipping gate.mk install"
  elif [ -e "$TARGET/make/gate.mk" ]; then
    echo "  ⚠ target already has make/gate.mk — left it"
  else
    cp "$ex" "$TARGET/make/gate.mk"
    echo "  → installed make/gate.mk from $GATE_FLAVOR example (edit GATE_STEPS to real checks)"
  fi
fi

cat <<'EOF'

✅ harness copied. Now fill the slots (the adopt-harness skill does this with you):
  1. CLAUDE.md         — the <FILL> lines: what/stack/structure/conventions/hotspots
  2. make/gate.mk      — set GATE_STEPS to this repo's REAL checks (+ custom linters)
  3. agent_docs/       — architecture.md + glossary.md: how THIS codebase works
Then: `make setup && make check` on a fresh clone → green.
EOF
