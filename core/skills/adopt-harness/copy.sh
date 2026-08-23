#!/usr/bin/env bash
# copy.sh — the MECHANICAL half of adopting this harness into a target repo.
#
# The manifest arrays below define what travels. The adopt-harness SKILL drives this
# (copy → scout the target → draft the fills → verify); standalone it just does the copy and
# prints the fill checklist.
#
# Usage:  copy.sh [--resolve <path>=<upstream|local|omit>]... <target-repo-path> [python|ts|none]
#   arg2 = which gate.example to install as the repo's make/gate.mk (default: none).
#         copy.sh --check <target-repo-path>
#   reports how far behind this harness the repo's adoption is (decision O), plus the
#   per-entry state (held/conflict) from .agents/MANIFEST.
#   exit 0 = up to date · 1 = behind or conflicted · 2 = cannot tell (no stamp, unknown commit)
#
#         copy.sh --doctor <target-repo-path>
#   verifies activation only (no copy): every hook present, bound per provider, fires clean.
#
# In the target, the harness is HOMED at the provider-neutral .agents/ root; .claude/ and
# .codex/ are thin adapters (symlinks and pointer tomls) both providers resolve through:
#   .agents/hooks/     the shared hook scripts — one copy, bound by both providers
#   .agents/briefs/    the subagent briefs — .claude/agents/*.md symlink here,
#                      .codex/agents/*.toml point here by path
#   .agents/skills/    the repo's skills — .claude/skills is a symlink to it (Codex
#                      scans .agents/skills natively)
#   .agents/MANIFEST   pristine hashes of every MANAGED entry, `shasum -c` format
#
# MANAGED entries update by a THREE-WAY comparison against the pristine hash recorded at
# install (same mechanism as install.sh's .install-manifest.sha256):
#   local unmodified, upstream moved  → refreshed
#   local modified, upstream same     → held (the repo's override wins, and is counted)
#   local modified, upstream moved    → CONFLICT — kept, reported, exit 1; resolve with
#                                       --resolve <path>=<upstream|local|omit>
# Never a silent keep across an upstream change, never a silent overwrite of a local one.
# Entries listed in adopt/CRITICAL fail-closed: their conflicts block the ✅ outright.
#
# ONCE entries (CLAUDE.md, AGENTS.md, docs scaffold, specs/README.md, make/gate.mk) are
# written only when absent — a repo fills these in and re-adoption must not undo that.
#
# Hook BINDINGS are the third class: they register behaviour, so they MERGE (keyed by
# event + script basename) instead of fill-once. The repo's own entries always survive;
# the run is not ✅ until the doctor sees every hook active.
set -euo pipefail

CHECK=0 DOCTOR=0
RESOLVES=""            # newline-separated "<path>=<disposition>" from --resolve
while [ $# -gt 0 ]; do
  case "$1" in
    --check)  CHECK=1; shift ;;
    --doctor) DOCTOR=1; shift ;;
    --resolve)
      [ $# -ge 2 ] || { echo "✗ --resolve needs <path>=<upstream|local|omit>" >&2; exit 1; }
      case "$2" in
        *=upstream|*=local|*=omit) RESOLVES="$RESOLVES$2"$'\n' ;;
        *) echo "✗ bad --resolve '$2' — want <path>=<upstream|local|omit>" >&2; exit 1 ;;
      esac
      shift 2 ;;
    *) break ;;
  esac
done
TARGET="${1:-}"
GATE_FLAVOR="${2:-none}"
[ -z "$TARGET" ] && { echo "usage: copy.sh [--check|--doctor] [--resolve p=d]... <target-repo-path> [python|ts|none]" >&2; exit 1; }
[ -d "$TARGET" ] || { echo "✗ target is not a directory: $TARGET" >&2; exit 1; }
TARGET="$(cd "$TARGET" && pwd)"

# Harness root = four levels up from core/skills/adopt-harness/.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
[ "$ROOT" = "$TARGET" ] && { echo "✗ refusing to adopt a repo into itself" >&2; exit 1; }
[ -d "$ROOT/adopt" ] || { echo "✗ no adopt/ payload at $ROOT/adopt" >&2; exit 1; }

note() { printf '  %s\n' "$*"; }
sha()  { shasum -a 256 "$1" | cut -d' ' -f1; }

STAMP_REL=".agents/harness-version"
OLD_STAMP_REL=".claude/harness-version"
MANIFEST="$TARGET/.agents/MANIFEST"

if [ "$DOCTOR" -eq 1 ]; then
  command -v python3 >/dev/null 2>&1 || { echo "✗ python3 is required for the doctor" >&2; exit 1; }
  exec python3 "$HERE/doctor.py" "$ROOT" "$TARGET"
fi

command -v shasum >/dev/null 2>&1 || { echo "✗ shasum is required" >&2; exit 1; }

# ── The MANIFEST: one line per managed entry, `<sha256>  <path>` (shasum -c compatible).
# A deliberate local deletion is a tombstone: `omitted:<upstream-sha-at-omit>  <path>`.
man_get() {  # -> pristine hash (or omitted:<sha>) for a path, empty if unrecorded
  [ -f "$MANIFEST" ] || return 0
  awk -v p="$1" '/^#/{next}{h=$1; sub(/^[^ ]+  /,""); if ($0==p) print h}' "$MANIFEST"
}
man_set() {  # record/replace one entry
  local path="$1" hash="$2" tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/manifest.XXXXXX")"
  { [ -f "$MANIFEST" ] && awk -v p="$path" '/^#/{next}{l=$0; sub(/^[^ ]+  /,"",l); if (l!=p) print $0}' "$MANIFEST"
    printf '%s  %s\n' "$hash" "$path"
  } | LC_ALL=C sort -k2 >"$tmp"
  mkdir -p "$(dirname "$MANIFEST")"
  { printf '# pristine hashes of harness-managed entries — written by adopt-harness/copy.sh\n'
    printf '# verify: grep -v "^#\\|^omitted" .agents/MANIFEST | shasum -c\n'
    cat "$tmp"; } >"$MANIFEST.new" && mv "$MANIFEST.new" "$MANIFEST"
  rm -f "$tmp"
}
man_drop() {
  [ -f "$MANIFEST" ] || return 0
  local tmp; tmp="$(mktemp "${TMPDIR:-/tmp}/manifest.XXXXXX")"
  awk -v p="$1" '{l=$0; if (l !~ /^#/) {sub(/^[^ ]+  /,"",l)}; if (l!=p || $0 ~ /^#/) print $0}' "$MANIFEST" >"$tmp" \
    && mv "$tmp" "$MANIFEST"
}
resolution_for() {  # -> disposition chosen via --resolve for this path, if any
  printf '%s' "$RESOLVES" | awk -F= -v p="$1" '$1==p{print $2; exit}'
}
is_critical() {
  [ -f "$ROOT/adopt/CRITICAL" ] || return 1
  grep -qxF "$1" <(grep -v '^#' "$ROOT/adopt/CRITICAL")
}

# ── What travels. MANAGED = three-way updated; ONCE = written only when absent.
# Directory payloads (hooks, briefs, tomls, spec templates) are enumerated per FILE so the
# state table, conflict reporting, and pruning apply to each entry individually.
MANAGED_STATIC=(
  "adopt/Makefile:Makefile"
  "adopt/make/gate.example-python.mk:make/gate.example-python.mk"
  "adopt/make/gate.example-ts.mk:make/gate.example-ts.mk"
)
ONCE=(
  "adopt/CLAUDE.template.md:CLAUDE.md"
  "adopt/AGENTS.template.md:AGENTS.md"
  "adopt/specs/README.md:specs/README.md"
  "adopt/docs/INDEX.md:docs/INDEX.md"
  "adopt/docs/architecture.md:docs/architecture.md"
  "adopt/docs/glossary.md:docs/glossary.md"
  "adopt/docs/adrs/README.md:docs/adrs/README.md"
  "adopt/docs/adrs/0000-template.md:docs/adrs/0000-template.md"
)
managed_entries() {  # emits "src:dst" for every managed entry, sorted by dst
  {
    printf '%s\n' "${MANAGED_STATIC[@]}"
    for f in "$ROOT"/adopt/hooks/*.sh;         do [ -e "$f" ] && echo "adopt/hooks/$(basename "$f"):.agents/hooks/$(basename "$f")"; done
    for f in "$ROOT"/adopt/agents/*.md;        do [ -e "$f" ] && echo "adopt/agents/$(basename "$f"):.agents/briefs/$(basename "$f")"; done
    for f in "$ROOT"/adopt/codex/agents/*.toml; do [ -e "$f" ] && echo "adopt/codex/agents/$(basename "$f"):.codex/agents/$(basename "$f")"; done
    (cd "$ROOT" && find adopt/specs/templates -type f 2>/dev/null) | while IFS= read -r rel; do
      echo "$rel:specs/${rel#adopt/specs/}"
    done
  } | LC_ALL=C sort -t: -k2
}

# ── Decision O's check: the stamp against THIS harness clone, measured by git, never guessed —
# now with the per-entry MANIFEST state alongside the repo-level distance.
if [ "$CHECK" -eq 1 ]; then
  name="$(basename "$TARGET")"
  stamp_file="$TARGET/$STAMP_REL"
  [ -f "$stamp_file" ] || stamp_file="$TARGET/$OLD_STAMP_REL"   # pre-neutral-root adoptions
  [ -f "$stamp_file" ] || { echo "✗ $name has no $STAMP_REL — never adopted, or adopted before stamping existed. Re-run copy.sh to stamp it." >&2; exit 2; }
  stamp="$(head -1 "$stamp_file")"
  git -C "$ROOT" rev-parse HEAD >/dev/null 2>&1 || { echo "✗ this harness copy is not a git checkout — nothing to compare against" >&2; exit 2; }
  git -C "$ROOT" cat-file -e "$stamp^{commit}" 2>/dev/null \
    || { echo "✗ stamp $stamp is not in this harness clone's history — fetch, or the repo was adopted from a different harness" >&2; exit 2; }
  ahead="$(git -C "$ROOT" rev-list --count "HEAD..$stamp")"
  if [ "$ahead" -gt 0 ]; then
    echo "? $name was adopted from a commit $ahead ahead of this clone — pull this clone first" >&2; exit 2
  fi
  behind="$(git -C "$ROOT" rev-list --count "$stamp..HEAD")"
  n_cur=0 n_held=0 n_conf=0
  if [ -f "$MANIFEST" ]; then
    while IFS= read -r pair; do
      src="$ROOT/${pair%%:*}"; rel="${pair#*:}"; dst="$TARGET/$rel"
      P="$(man_get "$rel")"; U="$(sha "$src")"
      case "$P" in
        "")          [ -f "$dst" ] && { [ "$(sha "$dst")" = "$U" ] && n_cur=$((n_cur+1)) || n_conf=$((n_conf+1)); } ;;
        omitted:*)   [ "${P#omitted:}" = "$U" ] || n_conf=$((n_conf+1)) ;;
        *) if [ ! -f "$dst" ]; then n_conf=$((n_conf+1))
           else L="$(sha "$dst")"
             if   [ "$L" = "$P" ]; then n_cur=$((n_cur+1))          # current or refresh-pending
             elif [ "$U" = "$P" ]; then n_held=$((n_held+1))
             else n_conf=$((n_conf+1)); fi
           fi ;;
      esac
    done < <(managed_entries)
    echo "  entries: $n_cur in step · $n_held held (local overrides) · $n_conf conflict(s)"
  fi
  if [ "$behind" -eq 0 ] && [ "$n_conf" -eq 0 ]; then
    echo "✓ $name is up to date with this harness ($(git -C "$ROOT" rev-parse --short HEAD))"; exit 0
  fi
  [ "$behind" -gt 0 ] && echo "⚠ $name is $behind commit(s) behind this harness (adopted at $(git -C "$ROOT" rev-parse --short "$stamp"), harness at $(git -C "$ROOT" rev-parse --short HEAD))"
  [ "$n_conf" -gt 0 ] && echo "⚠ $n_conf managed entr(ies) in conflict — re-run adoption to see and resolve them"
  echo "  re-running adoption is the supported upgrade path:  copy.sh $TARGET"
  exit 1
fi

echo "→ adopting harness from $ROOT into $TARGET"

# ── Layout migration: the skills HOME is .agents/skills; .claude/skills is the adapter symlink.
# Pre-neutral-root repos have the exact inverse (.agents/skills → .claude/skills). Invert it.
if [ -L "$TARGET/.agents/skills" ]; then
  rm "$TARGET/.agents/skills"     # the old inverse link; its target dir is handled next
fi
# A repo may TRACK its skills at .claude/skills. Moving that home stages a deletion of every
# tracked file in it — on a repo you may not own, one commit-everything away from erasing them.
# Git tracking is the signal: it says the team, not the harness, owns that path. Found in the
# wild 2026-08-22 (smoke: 17 tracked files under .claude/skills would have been staged deleted).
tracked_in() { git -C "$TARGET" ls-files "$1" 2>/dev/null | head -1; }
c_tracked=""; a_tracked=""
if command -v git >/dev/null 2>&1 && git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
  c_tracked="$(tracked_in .claude/skills)"
  a_tracked="$(tracked_in .agents/skills)"
fi

if [ -n "$c_tracked" ] && [ -n "$a_tracked" ]; then
  # Both homes hold tracked files. Neither direction is safe — either one stages deletions.
  # Leave both exactly as they are and say so; reconciling a duplicated skill is the repo's call.
  note "⚠ BOTH .claude/skills and .agents/skills hold git-TRACKED files — neither home was touched."
  note "  Moving either would stage its files for deletion. Reconcile them in the repo, then re-run."
elif [ -n "$c_tracked" ]; then
  # The repo owns .claude/skills. Keep it as the real home and point .agents/skills at it — the
  # pre-neutral-root arrangement: Codex scans .agents/skills and follows the link.
  if [ -e "$TARGET/.agents/skills" ] && [ ! -L "$TARGET/.agents/skills" ]; then
    (cd "$TARGET/.agents/skills" && tar cf - .) | (cd "$TARGET/.claude/skills" && tar xf -)
    rm -rf "$TARGET/.agents/skills"
  fi
  [ -L "$TARGET/.agents/skills" ] && rm -f "$TARGET/.agents/skills"
  mkdir -p "$TARGET/.agents"
  ln -s ../.claude/skills "$TARGET/.agents/skills"
  note "→ .claude/skills holds git-TRACKED files — left as the home; .agents/skills → ../.claude/skills"
  note "  (moving it would stage those files for deletion; the repo owns that path, not the harness)"
elif [ -L "$TARGET/.claude/skills" ]; then
  mkdir -p "$TARGET/.agents/skills"   # the link's intended home; harmless if it points elsewhere
elif [ -d "$TARGET/.claude/skills" ]; then
  mkdir -p "$TARGET/.agents/skills"
  (cd "$TARGET/.claude/skills" && tar cf - .) | (cd "$TARGET/.agents/skills" && tar xf -)
  rm -rf "$TARGET/.claude/skills"
  ln -s ../.agents/skills "$TARGET/.claude/skills"
  note "→ .claude/skills moved to .agents/skills (now the home; .claude/skills is a symlink)"
else
  mkdir -p "$TARGET/.agents/skills" "$TARGET/.claude"
  ln -s ../.agents/skills "$TARGET/.claude/skills"
  note "→ .agents/skills created; .claude/skills → ../.agents/skills"
fi

# ── MANAGED: the three-way loop.
# A --resolve for a path the payload does not manage is a mistake, not a no-op.
printf '%s' "$RESOLVES" | while IFS='=' read -r rp rd; do
  [ -z "$rp" ] && continue
  managed_entries | awk -F: -v r="$rp" '$2==r{f=1} END{exit !f}' \
    || { echo "✗ --resolve $rp: not a managed entry" >&2; exit 1; }
done || exit 1

n_add=0 n_cur=0 n_ref=0 n_held=0 n_prune=0 n_resolved=0
conflicts=""     # newline list: "<path>\t<why>"
added=""         # entries fresh-installed THIS run — migration may lay old-home edits over them

install_entry() {  # src dst rel
  mkdir -p "$(dirname "$2")"
  cp -p "$1" "$2"
}

while IFS= read -r pair; do
  src="$ROOT/${pair%%:*}"; rel="${pair#*:}"; dst="$TARGET/$rel"
  U="$(sha "$src")"; P="$(man_get "$rel")"
  L=""; [ -f "$dst" ] && L="$(sha "$dst")"

  disp="$(resolution_for "$rel")"
  if [ -n "$disp" ]; then
    case "$disp" in
      upstream) install_entry "$src" "$dst"; man_set "$rel" "$U"; note "→ $rel (resolved: upstream)" ;;
      local)    [ -n "$L" ] || { echo "✗ --resolve $rel=local, but no local file exists" >&2; exit 1; }
                # Record the UPSTREAM hash, not the local one: the entry stays classified as
                # held, and the NEXT upstream change conflicts again — a new fix needs a new
                # decision. Recording local would read as unmodified and the next run would
                # silently refresh over the version this resolution just chose to keep.
                man_set "$rel" "$U"; note "→ $rel (resolved: local — held against the current harness version)" ;;
      omit)     rm -f "$dst"; man_set "$rel" "omitted:$U"; note "→ $rel (resolved: omitted)" ;;
    esac
    n_resolved=$((n_resolved+1)); continue
  fi

  case "$P" in
    "")
      if [ -z "$L" ]; then
        install_entry "$src" "$dst"; man_set "$rel" "$U"; n_add=$((n_add+1)); added="$added$rel"$'\n'
      elif [ "$L" = "$U" ]; then
        man_set "$rel" "$U"; n_cur=$((n_cur+1))            # pre-MANIFEST adoption, in step
      else
        conflicts="$conflicts$rel"$'\t'"an existing file differs from the incoming harness entry"$'\n'
      fi ;;
    omitted:*)
      if [ "${P#omitted:}" = "$U" ]; then n_cur=$((n_cur+1))
      else conflicts="$conflicts$rel"$'\t'"upstream changed an entry this repo omitted — re-decide"$'\n'; fi ;;
    *)
      if [ -z "$L" ]; then
        conflicts="$conflicts$rel"$'\t'"managed entry is missing — deleted locally? (--resolve …=omit to keep it gone)"$'\n'
      elif [ "$L" = "$P" ]; then
        if [ "$U" = "$P" ]; then n_cur=$((n_cur+1))
        else install_entry "$src" "$dst"; man_set "$rel" "$U"; n_ref=$((n_ref+1)); fi
      else
        if [ "$U" = "$P" ]; then n_held=$((n_held+1))
        else conflicts="$conflicts$rel"$'\t'"BOTH changed: locally edited AND the harness moved on"$'\n'; fi
      fi ;;
  esac
done < <(managed_entries)

# Prune: recorded entries the payload no longer provides. Unmodified → removed with the entry;
# modified → the file stays as the repo's own, only the record is dropped.
if [ -f "$MANIFEST" ]; then
  while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    managed_entries | awk -F: -v r="$rel" '$2==r{f=1} END{exit !f}' && continue
    P="$(man_get "$rel")"; dst="$TARGET/$rel"
    case "$P" in omitted:*) man_drop "$rel"; continue ;; esac
    if [ ! -f "$dst" ]; then man_drop "$rel"
    elif [ "$(sha "$dst")" = "$P" ]; then rm -f "$dst"; man_drop "$rel"; n_prune=$((n_prune+1)); note "→ $rel pruned (removed upstream)"
    else man_drop "$rel"; note "⚠ $rel removed upstream but locally modified — left as the repo's own"; fi
  done < <(awk '!/^#/{sub(/^[^ ]+  /,""); print}' "$MANIFEST")
fi

chmod +x "$TARGET"/.agents/hooks/*.sh 2>/dev/null || true

# ── Adapter symlinks for the briefs: .claude/agents/<x>.md → ../../.agents/briefs/<x>.md.
# A pre-neutral-root repo has real files here, identical to the briefs — replace those with
# links; a file with its own content is the repo's own agent and is never touched.
mkdir -p "$TARGET/.claude/agents"
for src in "$ROOT"/adopt/agents/*.md; do
  [ -e "$src" ] || continue
  b="$(basename "$src")"; link="$TARGET/.claude/agents/$b"; briefrel="../../.agents/briefs/$b"
  if [ -L "$link" ]; then
    [ "$(readlink "$link")" = "$briefrel" ] || { rm "$link"; ln -s "$briefrel" "$link"; note "→ .claude/agents/$b relinked"; }
  elif [ -f "$link" ]; then
    if [ -f "$TARGET/.agents/briefs/$b" ] && { cmp -s "$link" "$TARGET/.agents/briefs/$b" || cmp -s "$link" "$src"; }; then
      rm "$link"; ln -s "$briefrel" "$link"; note "→ .claude/agents/$b was a duplicate — now a symlink to the brief"
    elif printf '%s' "$added" | grep -qxF ".agents/briefs/$b"; then
      # Migration: the repo had TUNED this brief at the old home. Its content is what both
      # providers were actually running — carry it to the neutral home as a held override
      # rather than silently switching the repo to the harness version.
      mv "$link" "$TARGET/.agents/briefs/$b"
      ln -s "$briefrel" "$link"
      note "→ .claude/agents/$b carried its local edits to .agents/briefs/ (held override)"
    else
      note "⚠ .claude/agents/$b has its own content — left as the repo's own agent"
    fi
  else
    ln -s "$briefrel" "$link"; note "→ .claude/agents/$b → $briefrel"
  fi
done

# ── Migration: hook copies at the old home (.claude/hooks/) are dead weight once bindings
# point at .agents/hooks/. An unmodified copy is removed; a modified one is left and named.
for src in "$ROOT"/adopt/hooks/*.sh; do
  b="$(basename "$src")"; old="$TARGET/.claude/hooks/$b"
  [ -f "$old" ] || continue
  if cmp -s "$old" "$src" || { [ -f "$TARGET/.agents/hooks/$b" ] && cmp -s "$old" "$TARGET/.agents/hooks/$b"; }; then
    rm -f "$old"; note "→ removed old copy .claude/hooks/$b (home is .agents/hooks/)"
  elif printf '%s' "$added" | grep -qxF ".agents/hooks/$b"; then
    # Migration: same reasoning as the briefs — the edited old-home hook is the behavior the
    # repo actually ran; carry it forward as a held override instead of silently rebinding to
    # the harness version and stranding the edit.
    mv "$old" "$TARGET/.agents/hooks/$b"
    chmod +x "$TARGET/.agents/hooks/$b" 2>/dev/null || true
    note "→ .claude/hooks/$b carried its local edits to .agents/hooks/ (held override)"
  else
    note "⚠ .claude/hooks/$b differs from the harness hook — left, but NOTHING binds it now"
  fi
done
rmdir "$TARGET/.claude/hooks" 2>/dev/null || true

# ── ONCE: written only when absent.
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

# ── Hook bindings MERGE (see header): the repo's own hooks survive, ours are added once, and a
# stale command form (e.g. the old .claude/hooks path) in OUR file is upgraded in place.
# Claude reads settings.json AND settings.local.json; harness bindings go in LOCAL (untracked
# by convention) so a team-owned settings.json is never dirtied. It is passed as a sibling so a
# hook the team already bound there is not duplicated.
command -v python3 >/dev/null 2>&1 || { echo "✗ python3 is required to merge hook bindings" >&2; exit 1; }
note "→ .claude/settings.local.json: $(python3 "$HERE/merge-hook-bindings.py" \
  "$ROOT/adopt/settings.json" "$TARGET/.claude/settings.local.json" "$TARGET/.claude/settings.json")"
note "→ .codex/hooks.json: $(python3 "$HERE/merge-hook-bindings.py" \
  "$ROOT/adopt/codex/hooks.json" "$TARGET/.codex/hooks.json")"

# ── Decision O: hook scripts are copied per repo (decision K), so a fix reaches a repo only by
# re-adoption — the stamp is what lets a check say "this repo is N commits behind". Refreshed on
# every run; fails open when the harness copy has no git history to record.
if src_sha="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null)"; then
  mkdir -p "$TARGET/.agents"
  {
    printf '%s\n' "$src_sha"
    printf '# harness source commit at adoption — written by adopt-harness/copy.sh (decision O)\n'
    printf '# staleness: run  copy.sh --check <this-repo>  from a harness clone\n'
    git -C "$ROOT" diff --quiet HEAD 2>/dev/null || printf '# the harness working tree was DIRTY at adoption; the stamp understates it\n'
  } >"$TARGET/$STAMP_REL"
  rm -f "$TARGET/$OLD_STAMP_REL"
  note "→ $STAMP_REL ($(git -C "$ROOT" rev-parse --short HEAD))"
else
  note "⚠ harness copy has no git history — no version stamp written"
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

# ── Coverage: held entries are the drift the version stamp cannot see; say the numbers every run.
echo
echo "  managed: $n_cur in step · $n_add added · $n_ref refreshed · $n_held held (local overrides)"\
"· $n_prune pruned · $n_resolved resolved"

if [ -n "$conflicts" ]; then
  echo
  echo "✗ CONFLICT — never silently kept, never silently overwritten:" >&2
  printf '%s' "$conflicts" | while IFS=$'\t' read -r rel why; do
    [ -z "$rel" ] && continue
    if is_critical "$rel"; then echo "    ✗ $rel — $why  [CRITICAL: blocks adoption until resolved]" >&2; else echo "    ✗ $rel — $why" >&2; fi
  done
  echo "  resolve each explicitly, then re-run:" >&2
  echo "    copy.sh --resolve <path>=upstream   take the harness version" >&2
  echo "    copy.sh --resolve <path>=local      keep the repo's version (becomes its pristine)" >&2
  echo "    copy.sh --resolve <path>=omit       the repo deliberately drops this entry" >&2
  exit 1
fi

# ── No ✅ on faith: the doctor must see every hook present, bound, and firing (CONTRACT §5).
echo
if ! python3 "$HERE/doctor.py" "$ROOT" "$TARGET"; then
  echo "✗ copied, but activation FAILED verification — fix the red rows above and re-run" >&2
  exit 1
fi

cat <<'EOF'

✅ harness copied and verified active. Now fill the slots (the adopt-harness skill does this with you):
  1. AGENTS.md    — the <FILL> lines: what/stack/structure/conventions/hotspots.
                    It is THE profile; CLAUDE.md just imports it. Do not restate it there.
  2. make/gate.mk — set GATE_STEPS to this repo's REAL checks
  3. docs/        — architecture.md + glossary.md: how THIS codebase works (start at INDEX.md)
Then: `make setup && make check` on a fresh clone → green.
EOF
