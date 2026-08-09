#!/usr/bin/env bash
# install.sh — publish core/ to ~/.agents/.
#
# ~/.agents/ is an installed projection, never a source. This script owns every byte in it.
#
# The refusal that matters: a file you edited *in ~/.agents/* stops the run, because that edit
# exists nowhere else and installing would destroy it. Distinguishing your edit from a legitimate
# source change needs a record of what was last installed — that is .install-manifest.sha256,
# written into the tree at the end of every apply. Without it (first run, or a tree this script
# never wrote) anything differing from core/ is treated as your edit and refuses. That is why the
# first run on this machine is expected to be a two-step.
#
# Everything derives from $HOME, so `HOME=/tmp/sandbox ./install.sh` exercises every path without
# touching the real machine.
set -euo pipefail

DRY_RUN=0 PRUNE=0 FORCE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --prune)   PRUNE=1 ;;
    --force)   FORCE=1 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      echo
      echo "usage: install.sh [--dry-run] [--prune] [--force]"
      echo "  --dry-run  report the plan, write nothing, exit non-zero if it would refuse"
      echo "  --prune    drop files in ~/.agents/ that core/ no longer provides (opt-in)"
      echo "  --force    install over locally-edited files, losing them"
      exit 0 ;;
    *) echo "install.sh: unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO/core"
DEST="$HOME/.agents"
BACKUP="$HOME/.agents.prev"
BIN_DIR="$HOME/.local/bin"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
REG_SRC="$CFG/depot/projects.yaml"
REG_DST="$CFG/agents/projects.yaml"
MANIFEST_REL=".install-manifest.sha256"
SWAP_FLAG="$HOME/.agents.swap-in-progress"

say()  { printf '%s\n' "$*"; }
step() { printf '\n\033[1m%s\033[0m\n' "$*"; }
die()  { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
# Symlinks are walked too. Without -type l a link in ~/.agents/ is invisible to the whole
# add/update/same/edited/extra accounting: it is never listed under "keep" and the swap silently
# discards it, so the "nothing is dropped without --prune" promise would not cover it.
# core/ and adopt/ are asserted symlink-free by the gate, so this only ever fires on the
# destination side and publishing a symlink never needs a defined meaning.
rels() { (cd "$1" && find . \( -type f -o -type l \) ! -name "$MANIFEST_REL" | sed 's|^\./||' | LC_ALL=C sort); }

[ -d "$SRC" ] || die "no core/ payload at $SRC"
command -v shasum >/dev/null || die "shasum not found"

# ~/.agents must be a real directory. The swap below replaces the whole tree, so a symlink here is
# consumed and its target's files are silently adopted as machine-wide extras. Provider homes
# symlink INTO ~/.agents, never the reverse (CONTRACT §5) — and ~/.claude is that exact shape
# today, so the mistake is one keystroke away.
if [ -L "$DEST" ]; then
  die "$DEST is a symlink to $(readlink "$DEST").
  ~/.agents/ must be a real directory: install.sh replaces the whole tree, which would
  consume the link and adopt its target's files. Move or remove the link, then re-run."
fi

# An interrupted swap leaves the tree at $BACKUP and no $DEST. Say so before doing anything else.
if [ -e "$SWAP_FLAG" ]; then
  say "⚠ a previous run was interrupted mid-swap."
  if [ ! -d "$DEST" ] && [ -d "$BACKUP" ]; then
    die "recover with:  mv '$BACKUP' '$DEST'    then re-run"
  fi
  say "  ~/.agents/ is present, so the swap completed; clearing the flag."
  [ "$DRY_RUN" -eq 1 ] || rm -f "$SWAP_FLAG"
fi

# ── The governing invariant: ~/.agents/ is a sync/version candidate, so no secret may enter it.
SECRET_RE='(sk-[A-Za-z0-9_-]{16,}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)'
scan_secrets() {
  local root="$1" label="$2" hits
  hits="$(grep -rIlE "$SECRET_RE" "$root" 2>/dev/null || true)"
  [ -n "$hits" ] && die "$label contains what looks like a secret:"$'\n'"$hits"
  hits="$(find "$root" -type f \( -name '.env' -o -name '.env.*' -o -name 'secrets.env' -o -name 'auth.json' \) 2>/dev/null || true)"
  [ -n "$hits" ] && die "$label contains a secret-bearing file:"$'\n'"$hits"
  return 0
}
scan_secrets "$SRC" "core/"

# ── Capability report. Verified, never asserted: a missing capability is reported, not fatal.
step "Provider capabilities"
cli="$(command -v claude 2>/dev/null || true)"
if [ -n "$cli" ]; then
  real="$(readlink -f "$cli" 2>/dev/null || echo "$cli")"
  say "  claude          $("$cli" --version 2>/dev/null | head -1 || echo '(version unavailable)')"
  for cap in WorktreeCreateHook baseRef bgIsolation; do
    if LC_ALL=C grep -qa "$cap" "$real" 2>/dev/null; then
      say "  ✓ $cap"
    else
      say "  ✗ $cap — not found in the installed CLI"
    fi
  done
else
  say "  ✗ claude not on PATH — capability check skipped"
fi
say "  · worktree location (Claude Desktop) and worktree root (Codex) are GUI settings and"
say "    cannot be read here. Wave 1 T1.7 confirms them; both degrade safely if absent."

# ── Plan: classify every file.
step "Plan"
# Stage inside $HOME, not $TMPDIR: the install below finishes with `mv staging $DEST`, and a
# rename is only atomic within one filesystem. $TMPDIR is a separate mount often enough (tmpfs
# /tmp, containers, a network-mounted $HOME) that relying on them matching is a portability bug.
rm -rf "$HOME"/.agents.staging.* 2>/dev/null || true   # a hard kill can leave one behind
tmpd="$(mktemp -d "$HOME/.agents.staging.XXXXXX")"; trap 'rm -rf "$tmpd"' EXIT
: >"$tmpd/add"; : >"$tmpd/update" ; : >"$tmpd/same"; : >"$tmpd/edited"; : >"$tmpd/extra"

have_manifest=0
[ -f "$DEST/$MANIFEST_REL" ] && have_manifest=1

installed_sha() {
  [ "$have_manifest" -eq 1 ] || return 1
  # The path is everything after the hash and its two-space separator — $2 would stop at the
  # first space, so a path containing one never matches and the file is refused as "edited"
  # forever, blaming a local edit that does not exist.
  local s; s="$(awk -v p="$1" '{h=$1; sub(/^[^ ]+  /,""); if ($0==p) print h}' "$DEST/$MANIFEST_REL")"
  [ -n "$s" ] && { printf '%s' "$s"; return 0; } || return 1
}

while IFS= read -r rel; do
  [ -z "$rel" ] && continue
  if [ ! -e "$DEST/$rel" ]; then
    echo "$rel" >>"$tmpd/add"; continue
  fi
  cur="$(sha "$DEST/$rel")"
  src="$(sha "$SRC/$rel")"
  if [ "$cur" = "$src" ]; then
    echo "$rel" >>"$tmpd/same"
  elif rec="$(installed_sha "$rel")" && [ "$rec" = "$cur" ]; then
    echo "$rel" >>"$tmpd/update"        # untouched since install; core/ moved on
  else
    echo "$rel" >>"$tmpd/edited"        # differs from core/ AND is not what we installed
  fi
done < <([ -d "$SRC" ] && rels "$SRC")

if [ -d "$DEST" ]; then
  while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    [ -e "$SRC/$rel" ] || echo "$rel" >>"$tmpd/extra"
  done < <(rels "$DEST")
fi

n_add=$(wc -l <"$tmpd/add" | tr -d ' ')
n_upd=$(wc -l <"$tmpd/update" | tr -d ' ')
n_same=$(wc -l <"$tmpd/same" | tr -d ' ')
n_edit=$(wc -l <"$tmpd/edited" | tr -d ' ')
n_extra=$(wc -l <"$tmpd/extra" | tr -d ' ')

say "  add     $n_add"
say "  update  $n_upd"
say "  same    $n_same"
if [ "$n_extra" -gt 0 ]; then
  if [ "$PRUNE" -eq 1 ]; then say "  prune   $n_extra"; else say "  keep    $n_extra  (in ~/.agents/, not in core/ — --prune to drop)"; fi
  sed 's/^/            /' "$tmpd/extra"
fi

if [ "$n_edit" -gt 0 ]; then
  say ""
  say "  ✗ $n_edit file(s) in $DEST differ from core/ and are not what install.sh last wrote."
  say "    ~/.agents/ is a projection — these edits exist nowhere else and would be destroyed."
  sed 's/^/      /' "$tmpd/edited"
  [ "$have_manifest" -eq 1 ] || say "    (no install manifest present, so every difference is treated as a local edit)"
  say ""
  say "    Reconcile each file — copy it into core/ if the edit is wanted, or overwrite it from"
  say "    core/ if it is not — then re-run. --force installs over them and loses them."
fi

if [ "$DRY_RUN" -eq 1 ]; then
  step "Dry run — nothing was written"
  [ "$n_edit" -gt 0 ] && [ "$FORCE" -eq 0 ] && exit 1
  exit 0
fi

[ "$n_edit" -gt 0 ] && [ "$FORCE" -eq 0 ] && exit 1

# ── Build the whole desired tree before touching $DEST.
step "Install"
staging="$tmpd/agents"
mkdir -p "$staging"
(cd "$SRC" && tar cf - .) | (cd "$staging" && tar xf -)

if [ "$PRUNE" -eq 0 ] && [ "$n_extra" -gt 0 ]; then
  while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    mkdir -p "$staging/$(dirname "$rel")"
    cp -Pp "$DEST/$rel" "$staging/$rel"   # -P: preserve the link itself; -p alone copies its target
  done <"$tmpd/extra"
fi

scan_secrets "$staging" "the staged tree"

(cd "$staging" && find . -type f ! -name "$MANIFEST_REL" | sed 's|^\./||' | LC_ALL=C sort \
  | while IFS= read -r rel; do printf '%s  %s\n' "$(sha "$rel")" "$rel"; done) >"$staging/$MANIFEST_REL"

touch "$SWAP_FLAG"
if [ -d "$DEST" ]; then
  # One backup is the decided design; discarding it silently is not. The recovery path from a bad
  # install is "restore ~/.agents.prev", and a reflexive second run is what destroys it.
  if [ -d "$BACKUP" ]; then
    say "  ⚠ replacing the previous backup at $BACKUP — it is the only copy of the tree"
    say "    installed before this one. Recover from it FIRST if you meant to."
  fi
  rm -rf "$BACKUP"
  mv "$DEST" "$BACKUP"
  say "  backup  $BACKUP"
fi
mv "$staging" "$DEST"
rm -f "$SWAP_FLAG"
say "  installed $(wc -l <"$DEST/$MANIFEST_REL" | tr -d ' ') files → $DEST"

# ── wt
step "wt"
if [ -f "$REPO/bin/wt" ]; then
  mkdir -p "$BIN_DIR"
  install -m 0755 "$REPO/bin/wt" "$BIN_DIR/wt"
  say "  installed → $BIN_DIR/wt"
  # wt must be able to create .workspace/ in a repo that never adopted the harness, so it needs
  # an initialiser outside any repo. Same source file copy.sh ships; a second destination.
  if [ -f "$REPO/adopt/hooks/ensure-workspace.sh" ]; then
    install -m 0755 "$REPO/adopt/hooks/ensure-workspace.sh" "$BIN_DIR/ensure-workspace.sh"
    say "  installed → $BIN_DIR/ensure-workspace.sh (fallback for unadopted repos)"
  fi
  if [ -f "$REPO/bin/workspace-record" ]; then
    install -m 0755 "$REPO/bin/workspace-record" "$BIN_DIR/workspace-record"
    say "  installed → $BIN_DIR/workspace-record"
  fi
  case ":$PATH:" in *":$BIN_DIR:"*) ;; *) say "  ⚠ $BIN_DIR is not on PATH" ;; esac
else
  say "  ✗ $REPO/bin/wt not found — skipped"
fi

# ── Registry: migrate only into an absent target, never over an existing one.
step "Registry"
if [ -e "$REG_DST" ]; then
  say "  already present, left untouched → $REG_DST"
elif [ -f "$REG_SRC" ]; then
  if [ -x "$REPO/install/migrate-registry.py" ]; then
    "$REPO/install/migrate-registry.py" "$REG_SRC" "$REG_DST" || die "registry migration failed"
  else
    mkdir -p "$(dirname "$REG_DST")"
    cp -p "$REG_SRC" "$REG_DST"
    say "  copied unchanged (no migrate-registry.py) → $REG_DST"
  fi
  say "  the source registry is left untouched"
else
  say "  no registry at $REG_SRC — nothing to migrate"
fi

step "Done"
