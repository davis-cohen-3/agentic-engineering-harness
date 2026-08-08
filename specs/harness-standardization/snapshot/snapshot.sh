#!/usr/bin/env bash
# T0.1 — snapshot and checksum the machine's harness trees into this repo.
#
# READ-ONLY against the machine. Writes only inside this snapshot directory.
# Re-runnable: regenerates manifests and the content copy from scratch each time,
# so a second run against an unchanged machine produces an identical tree.
#
# Scope (plan/tasks.md T0.1): ~/.agents, ~/.codex/skills, ~/.claude/skills, ~/agents/claude.
# ~/.claude is a symlink to ~/agents/claude, so ~/.claude/skills is not a fourth unique
# tree — it resolves inside the third. Three unique roots are walked; nothing is counted twice.
#
# Two manifests, because they have two different consumers:
#   MANIFEST-content.sha256   authored harness content — the material at risk in Wave 1.
#                             Copied into trees/ as well as checksummed.
#   MANIFEST-runtime.sha256   provider runtime state and vendor-shipped files — checksummed
#                             as the inventory Wave 1 (T1.4/T1.5) needs before it moves or
#                             retires ~/agents/, but NOT copied. See README.md.
#
# Only the content zone is reproducible. The runtime zone covers live provider state
# (projects/, backups/, history.jsonl, …) that any running session mutates, so
# MANIFEST-runtime.sha256 differs between two runs by construction. Re-runs are checked
# against the CONTENT DIGEST printed at the end, not against the whole directory.
#
# secrets.env is checksummed for integrity and never copied. A checksum is not a secret value.

set -euo pipefail

SNAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTENT_MANIFEST="$SNAP_DIR/MANIFEST-content.sha256"
RUNTIME_MANIFEST="$SNAP_DIR/MANIFEST-runtime.sha256"
TREES="$SNAP_DIR/trees"

# Roots walked, relative to $HOME. Unique — no path is inside another.
ROOTS=(".agents" ".codex/skills" "agents/claude")

# A path (relative to $HOME) is CONTENT if it matches one of these prefixes, else RUNTIME.
is_content() {
  case "$1" in
    .agents/*)                              return 0 ;;
    .codex/skills/.system/*)                return 1 ;;   # vendor-shipped, reinstallable
    .codex/skills/*)                        return 0 ;;
    agents/claude/skills/*)                 return 0 ;;
    agents/claude/agents/*)                 return 0 ;;
    agents/claude/rules/*)                  return 0 ;;
    agents/claude/hooks/*)                  return 0 ;;
    agents/claude/commands/*)               return 0 ;;
    agents/claude/plans/*)                  return 0 ;;
    agents/claude/scheduled-tasks/*)        return 0 ;;
    agents/claude/settings.json)            return 0 ;;
    agents/claude/settings.json.backup)     return 0 ;;
    agents/claude/settings.local.json)      return 0 ;;
    agents/claude/mcp.json)                 return 0 ;;
    agents/claude/mcp-needs-auth-cache.json) return 0 ;;
    agents/claude/secrets.env)              return 0 ;;   # checksummed, never copied
    *)                                      return 1 ;;
  esac
}

# CONTENT paths that are checksummed but must never be copied into the repo.
is_never_copy() {
  case "$1" in
    agents/claude/secrets.env) return 0 ;;
    *)                         return 1 ;;
  esac
}

# Where a $HOME-relative content path lands under trees/.
dest_for() {
  case "$1" in
    .agents/*)        printf 'dot-agents/%s'   "${1#.agents/}" ;;
    .codex/skills/*)  printf 'codex-skills/%s' "${1#.codex/skills/}" ;;
    agents/claude/*)  printf 'claude-home/%s'  "${1#agents/claude/}" ;;
  esac
}

rm -rf "$TREES"
mkdir -p "$TREES"
: >"$CONTENT_MANIFEST.tmp"
: >"$RUNTIME_MANIFEST.tmp"

n_content=0 n_runtime=0 n_copied=0 n_skipped=0

while IFS= read -r -d '' abs; do
  rel="${abs#"$HOME/"}"
  sum="$(shasum -a 256 "$abs" | cut -d' ' -f1)"
  if is_content "$rel"; then
    printf '%s  ~/%s\n' "$sum" "$rel" >>"$CONTENT_MANIFEST.tmp"
    n_content=$((n_content + 1))
    if is_never_copy "$rel"; then
      n_skipped=$((n_skipped + 1))
    else
      dest="$TREES/$(dest_for "$rel")"
      mkdir -p "$(dirname "$dest")"
      cp -p "$abs" "$dest"
      n_copied=$((n_copied + 1))
    fi
  else
    printf '%s  ~/%s\n' "$sum" "$rel" >>"$RUNTIME_MANIFEST.tmp"
    n_runtime=$((n_runtime + 1))
  fi
done < <(
  for r in "${ROOTS[@]}"; do
    [ -e "$HOME/$r" ] && find "$HOME/$r" -type f -print0
  done | sort -z
)

sort -k2 "$CONTENT_MANIFEST.tmp" >"$CONTENT_MANIFEST" && rm -f "$CONTENT_MANIFEST.tmp"
sort -k2 "$RUNTIME_MANIFEST.tmp" >"$RUNTIME_MANIFEST" && rm -f "$RUNTIME_MANIFEST.tmp"

# Verify: every copied file's bytes in trees/ hash to what the source hashed to.
fail=0
while read -r sum rel; do
  rel="${rel#\~/}"
  is_never_copy "$rel" && continue
  dest="$TREES/$(dest_for "$rel")"
  if [ ! -f "$dest" ]; then
    echo "MISSING COPY: $rel" >&2
    fail=1
    continue
  fi
  got="$(shasum -a 256 "$dest" | cut -d' ' -f1)"
  if [ "$got" != "$sum" ]; then
    echo "CHECKSUM MISMATCH: $rel ($sum != $got)" >&2
    fail=1
  fi
done <"$CONTENT_MANIFEST"

# Nothing in the copy may be a secret-bearing file.
if [ -e "$TREES/claude-home/secrets.env" ]; then
  echo "FATAL: secrets.env was copied into the repo" >&2
  fail=1
fi

echo "content files : $n_content  (copied $n_copied, checksum-only $n_skipped)"
echo "runtime files : $n_runtime"
echo "total unique  : $((n_content + n_runtime))"
if [ "$fail" -ne 0 ]; then
  echo "VERIFY: FAILED" >&2
  exit 1
fi
echo "VERIFY: every content file in trees/ matches its source checksum"
echo "CONTENT DIGEST: $(shasum -a 256 "$CONTENT_MANIFEST" | cut -d' ' -f1)"
