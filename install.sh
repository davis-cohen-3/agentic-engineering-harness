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

DRY_RUN=0 PRUNE=0 FORCE=0 REVIEW=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --prune)   PRUNE=1 ;;
    --force)   FORCE=1 ;;
    --review)  REVIEW=1 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      echo
      echo "usage: install.sh [--dry-run] [--prune] [--force] [--review]"
      echo "  --dry-run  report the plan, write nothing, exit non-zero if it would refuse"
      echo "  --prune    drop files in ~/.agents/ that core/ no longer provides (opt-in;"
      echo "             never runs blind — a --review pass must precede it, decision N)"
      echo "  --force    install over locally-edited files, losing them"
      echo "  --review   inbox every machine-side extra and drift with a per-file disposition"
      echo "             (import into the repo / prune the machine side / leave), survey the"
      echo "             non-symlinked provider surfaces read-only, and record the review"
      echo "             that --prune requires. Installs nothing."
      exit 0 ;;
    *) echo "install.sh: unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
if [ "$REVIEW" -eq 1 ] && { [ "$DRY_RUN" -eq 1 ] || [ "$PRUNE" -eq 1 ] || [ "$FORCE" -eq 1 ]; }; then
  echo "install.sh: --review runs alone — it installs nothing, so the other modes do not combine" >&2
  exit 2
fi

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
REVIEW_STAMP="$HOME/.agents.reviewed"

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

# The extras' fingerprint is what a review stamps and what --prune checks against. Path AND
# content: a review judged the file's bytes, so an extra rewritten after the review is as
# unreviewed as one that appeared after it. Symlinks fingerprint by target, not through it —
# sha() on a dangling link fails, and the link itself is what the review looked at.
extra_id() {
  if [ -L "$DEST/$1" ]; then printf 'link:%s  %s\n' "$(readlink "$DEST/$1")" "$1"
  else printf '%s  %s\n' "$(sha "$DEST/$1")" "$1"; fi
}
extras_fingerprint() {
  [ -d "$DEST" ] || return 0
  rels "$DEST" | while IFS= read -r rel; do
    if [ -n "$rel" ] && [ ! -e "$SRC/$rel" ]; then extra_id "$rel"; fi
  done
  return 0
}

[ -d "$SRC" ] || die "no core/ payload at $SRC"
command -v shasum >/dev/null || die "shasum not found"

# ── Compose the effective source: core/ plus the subagent briefs, which are single-sourced
# from adopt/agents/ (the same files copy.sh ships to repos) rather than duplicated in core/.
# Everything downstream — classification, refusal, manifest — sees one coherent tree.
COMPOSED="$(mktemp -d "${TMPDIR:-/tmp}/agents-src.XXXXXX")"
trap 'rm -rf "$COMPOSED"' EXIT
(cd "$SRC" && tar cf - .) | (cd "$COMPOSED" && tar xf -)
if ls "$REPO"/adopt/agents/*.md >/dev/null 2>&1; then
  mkdir -p "$COMPOSED/claude/agents"
  cp -p "$REPO"/adopt/agents/*.md "$COMPOSED/claude/agents/"
fi
SRC="$COMPOSED"

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
tmpd="$(mktemp -d "$HOME/.agents.staging.XXXXXX")"; trap 'rm -rf "$tmpd" "$COMPOSED"' EXIT
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

# ── Review (decision N): the inbound sync channel. Every machine-side deviation — drift and
# extra — is an inbox item with a per-file disposition; nothing moves without an answer.
# Installs nothing; ends by recording the review --prune requires.
if [ "$REVIEW" -eq 1 ]; then
  n_imported=0 n_pruned=0 n_left=0

  # import = the machine copy enters the repo working tree, to be shipped by PR. The one thing
  # that may never ride this channel is a secret (§5's governing invariant) — refuse, not carry.
  import_into_repo() {
    case "$(basename "$1")" in
      .env|.env.*|secrets.env|auth.json)
        say "    ✗ import refused: secret-bearing filename — left in place"; return 1 ;;
    esac
    if [ ! -L "$DEST/$1" ] && grep -qIE "$SECRET_RE" "$DEST/$1" 2>/dev/null; then
      say "    ✗ import refused: contains what looks like a secret — left in place"; return 1
    fi
    # The composed source is a temp view; imports land in the REPO — briefs at their
    # single source (adopt/agents/), everything else in core/.
    local repo_dst
    case "$1" in
      claude/agents/*) repo_dst="$REPO/adopt/agents/$(basename "$1")" ;;
      *)               repo_dst="$REPO/core/$1" ;;
    esac
    mkdir -p "$(dirname "$repo_dst")"
    cp -Pp "$DEST/$1" "$repo_dst"
    say "    imported → ${repo_dst#"$REPO"/}  (uncommitted in the repo — ship it by PR)"
  }

  if [ "$((n_edit + n_extra))" -eq 0 ]; then
    step "Review — inbox empty: no drift, no extras"
  else
    step "Review — inbox: $n_edit drifted, $n_extra extra"
    say "  answers: i = import into the repo · p = prune the machine side · anything else = leave"
  fi

  while IFS= read -r rel <&3; do
    [ -z "$rel" ] && continue
    say ""
    say "  DRIFT  $rel — differs from core/ and is not what install.sh last wrote"
    { diff -u "$SRC/$rel" "$DEST/$rel" 2>/dev/null || true; } | sed -n '3,30p' | sed 's/^/      /'
    printf '  import / prune (restore from core/) / leave?  [i/p/L] '
    ans=""; IFS= read -r ans || true
    case "$ans" in
      [iI]) if import_into_repo "$rel"; then n_imported=$((n_imported+1)); else n_left=$((n_left+1)); fi ;;
      [pP]) cp -Pp "$SRC/$rel" "$DEST/$rel"
            say "    restored from core/ — the machine-side edit is discarded"
            n_pruned=$((n_pruned+1)) ;;
      *)    say "    left — install keeps refusing until it is reconciled"; n_left=$((n_left+1)) ;;
    esac
  done 3<"$tmpd/edited"

  while IFS= read -r rel <&3; do
    [ -z "$rel" ] && continue
    say ""
    if [ -L "$DEST/$rel" ]; then
      say "  EXTRA  $rel → $(readlink "$DEST/$rel") — in ~/.agents/, not in core/"
    else
      say "  EXTRA  $rel — in ~/.agents/, not in core/"
      sed -n '1,6p' "$DEST/$rel" 2>/dev/null | sed 's/^/      /'
    fi
    printf '  import / prune (delete from ~/.agents/) / leave?  [i/p/L] '
    ans=""; IFS= read -r ans || true
    case "$ans" in
      [iI]) if import_into_repo "$rel"; then n_imported=$((n_imported+1)); else n_left=$((n_left+1)); fi ;;
      [pP]) rm -f "$DEST/$rel"
            rmdir "$(dirname "$DEST/$rel")" 2>/dev/null || true   # the immediate dir only, never a walk up
            say "    deleted from ~/.agents/"
            n_pruned=$((n_pruned+1)) ;;
      *)    say "    left — a kept extra; --prune (after this review) drops it"; n_left=$((n_left+1)) ;;
    esac
  done 3<"$tmpd/extra"

  # The non-symlinked provider locations, read-only: provider-shipped novelties must be VISIBLE,
  # but judging a genuinely new kind of surface stays human (decision N) — no dispositions here.
  step "Provider surfaces — read-only survey"
  found_any=0
  for p in "$HOME/.claude/plugins" "$HOME/.claude/commands" "$HOME/.claude/skills" \
           "$HOME/.claude/agents"  "$HOME/.claude/hooks"    "$HOME/.claude/output-styles" \
           "$HOME/.codex/prompts"  "$HOME/.codex/skills"    "$HOME/.codex/agents" "$HOME/.codex/hooks"; do
    [ -e "$p" ] || [ -L "$p" ] || continue
    found_any=1
    disp="~${p#"$HOME"}/"
    if [ -L "$p" ]; then
      tgt="$(readlink "$p")"
      case "$tgt" in
        "$HOME/.agents/"*|*/.agents/*) say "  $disp → $tgt — governed (symlinked into ~/.agents/)" ;;
        *)                             say "  $disp → $tgt — a symlink pointing OUTSIDE ~/.agents/" ;;
      esac
    elif [ -d "$p" ]; then
      say "  $disp  $(find "$p" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ') entries: $(cd "$p" && ls -1 2>/dev/null | head -8 | tr '\n' ' ')"
    fi
  done
  [ "$found_any" -eq 1 ] || say "  none present"

  extras_fingerprint | shasum -a 256 | cut -d' ' -f1 >"$REVIEW_STAMP"

  step "Review complete — nothing was installed"
  say "  imported $n_imported · pruned $n_pruned · left $n_left"
  [ "$n_imported" -gt 0 ] && say "  imported files are uncommitted in $REPO — ship them by PR"
  say "  review recorded → $REVIEW_STAMP (what --prune requires)"
  exit 0
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

# ── Decision N: --prune never runs blind, and the review must have judged THESE extras — a
# stamp for a different set is no review at all. --dry-run exits above (it IS a preview), and
# pruning zero extras has nothing to be blind to.
if [ "$PRUNE" -eq 1 ] && [ "$n_extra" -gt 0 ]; then
  cur_fp="$(extras_fingerprint | shasum -a 256 | cut -d' ' -f1)"
  [ -f "$REVIEW_STAMP" ] || die "--prune never runs blind (decision N): no review on record for these $n_extra extra(s).
  Run  install.sh --review  first, then re-run with --prune."
  [ "$(head -1 "$REVIEW_STAMP" 2>/dev/null)" = "$cur_fp" ] || die "--prune refused: the extras in $DEST changed since the last review.
  Re-run  install.sh --review, then --prune."
fi

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
[ "$PRUNE" -eq 1 ] && rm -f "$REVIEW_STAMP"   # one review authorizes one prune
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

# ── Provider adapter: these provider surfaces are install.sh-owned (decision, 2026-08-21;
# extended to skills, 2026-08-25) — symlinks into the projection, so the briefs and skills load
# in every repo and update with every install. Linking skills is what keeps a personal skill out
# of every product repo's working tree: it lives in core/, not in a checkout. A real directory
# whose files all match the projection is upgraded to the link; one with its own content is left
# and named (--review surveys it; reconcile there first).
link_provider_surface() {  # $1 = link path, $2 = projection subdir
  local PA="$1" SRC="$DEST/$2"
  step "Provider adapter — ~${PA#"$HOME"}"
  if [ -L "$PA" ]; then
    case "$(readlink "$PA")" in
      "$SRC") say "  already linked → $SRC" ;;
      *) say "  ⚠ symlink points elsewhere ($(readlink "$PA")) — left it" ;;
    esac
  elif [ -d "$PA" ]; then
    local drift=0 f rel
    while IFS= read -r f; do
      rel="${f#"$PA"/}"
      cmp -s "$f" "$SRC/$rel" 2>/dev/null || { drift=1; say "  ⚠ $rel differs from the projection"; }
    done < <(find "$PA" -type f)
    if [ "$drift" -eq 0 ]; then
      rm -rf "$PA"
      ln -s "$SRC" "$PA"
      say "  real directory matched the projection — replaced with the symlink"
    else
      say "  left as a real directory — reconcile the drift (install.sh --review), then re-run"
    fi
  elif [ -d "$SRC" ]; then
    mkdir -p "$(dirname "$PA")"
    ln -s "$SRC" "$PA"
    say "  linked → $SRC"
  else
    say "  projection has no $2 — nothing to link"
  fi
}

# Skills are linked one at a time, never by claiming the whole directory. A provider ships its
# own skills into that path — Codex populates ~/.codex/skills/.system/ — so replacing the
# directory with a link would delete them, and refusing on their presence would mean the harness
# never installs a skill there at all. Per-skill links coexist with whatever the provider owns.
link_skills_into() {  # $1 = provider skills dir
  local PD="$1" SRC="$DEST/skills" name e
  step "Provider adapter — ~${PD#"$HOME"}"
  [ -d "$SRC" ] || { say "  projection has no skills — nothing to link"; return; }
  if [ -L "$PD" ]; then
    # An earlier whole-directory link of ours. Converge it on per-skill links so both providers
    # end in the same shape and neither keeps a claim on the whole surface.
    case "$(readlink "$PD")" in
      "$SRC") rm -f "$PD"; say "  whole-directory link replaced by per-skill links" ;;
      *)      say "  ⚠ symlink points elsewhere ($(readlink "$PD")) — left it"; return ;;
    esac
  fi
  mkdir -p "$PD"
  local n=0 kept=0
  for d in "$SRC"/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"; e="$PD/$name"
    if [ -L "$e" ]; then
      [ "$(readlink "$e")" = "$SRC/$name" ] || { say "  ⚠ $name links outside the projection — left it"; kept=$((kept+1)); continue; }
    elif [ -e "$e" ]; then
      say "  ⚠ $name exists and is not a link — left it (provider- or hand-owned)"; kept=$((kept+1)); continue
    else
      ln -s "$SRC/$name" "$e"
    fi
    n=$((n+1))
  done
  # A skill dropped from core/ leaves a dangling link that the provider still lists.
  local stale=0
  for e in "$PD"/*; do
    [ -L "$e" ] || continue
    case "$(readlink "$e")" in "$SRC"/*) [ -e "$e" ] || { rm -f "$e"; stale=$((stale+1)); } ;; esac
  done
  say "  $n skill(s) linked → $SRC$([ "$kept" -gt 0 ] && echo ", $kept left alone")$([ "$stale" -gt 0 ] && echo ", $stale stale link(s) removed")"
}

link_provider_surface "$HOME/.claude/agents" "claude/agents"
# Both providers read the SAME skills tree — one source, two entry points. A skill that only one
# provider should see does not belong in core/.
link_skills_into "$HOME/.claude/skills"
link_skills_into "$HOME/.codex/skills"

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
