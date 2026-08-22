#!/usr/bin/env bash
# WorktreeCreate hook (Claude-only — Codex has no equivalent event): route every worktree
# Claude creates to <container>/worktrees/<name>, the registry layout `wt` implements, instead
# of Claude's default .claude/worktrees/ INSIDE the checkout. One layout for wt-cut and
# Claude-cut worktrees, and a worktree cut FROM a worktree still lands in the project's
# worktrees/ — never nested beside the session (the failure that scattered smoke across
# five roots, 2026-08-21).
#
# CONTRACT (docs/en/worktrees.md): the hook REPLACES git worktree logic entirely. stdin JSON
# carries .name; stdout must be EXACTLY the created directory path (everything else → stderr);
# any non-zero exit fails creation. There is no harness registry lookup here on purpose: the
# hook always runs inside the repo, and <container>/worktrees IS the registry convention —
# resolving the container from git needs no second copy of wt's parsing.
#
# Degraded modes, in order: routed location unusable → Claude's default .claude/worktrees/;
# git cannot create a worktree at all → non-zero (identical to what the default would do).
set -uo pipefail

err() { printf 'route-worktree: %s\n' "$*" >&2; }

name=""
if command -v jq >/dev/null 2>&1; then
  name="$(jq -r '.name // empty' 2>/dev/null)"
fi
[ -n "$name" ] || name="wt-$(date +%s)-$$"   # no jq or no name: still isolate, generic name

# The name arrives from session input, which prompt-injected content can steer. It is ONE path
# component or it is replaced: a traversal like ../../<existing-dir> would otherwise hit the
# reuse branch below and root the new session at an arbitrary directory (found 2026-08-21).
case "$name" in
  .*|*/*|*\\*) err "invalid worktree name '$name' — using a generated one"
               name="wt-$(date +%s)-$$" ;;
esac

main_gitdir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" \
  || { err "not a git repository — cannot create a worktree"; exit 1; }
main_root="$(dirname "$main_gitdir")"

root="$(dirname "$main_root")/worktrees"
mkdir -p "$root" 2>/dev/null || { root="$main_root/.claude/worktrees"; mkdir -p "$root" || exit 1; }
dir="$root/$name"

# Reuse-by-name, as the default does — but only a directory git KNOWS as a worktree. A
# directory that merely exists at that path is not a session root we hand out.
if [ -d "$dir" ]; then
  phys="$(cd "$dir" 2>/dev/null && pwd -P)"
  if git -C "$main_root" worktree list --porcelain 2>/dev/null \
       | grep -q -e "^worktree $dir\$" -e "^worktree ${phys:-$dir}\$"; then
    err "reusing existing worktree $dir"
    printf '%s\n' "$dir"
    exit 0
  fi
  err "$dir exists but is not a registered worktree — refusing to open a session there"
  exit 1
fi

# Base ref mirrors the default "fresh" behaviour (and wt's rule): the remote default branch,
# falling back to HEAD when there is no usable remote. No fetch — hooks must be fast.
base=""
for c in origin/main origin/master; do
  git -C "$main_root" rev-parse --verify --quiet "$c" >/dev/null && { base="$c"; break; }
done
[ -n "$base" ] || base="HEAD"

branch="worktree-$name"
if git -C "$main_root" show-ref --verify --quiet "refs/heads/$branch"; then
  branch="$branch-$(date +%s)"
fi
git -C "$main_root" worktree add -b "$branch" "$dir" "$base" --quiet >&2 \
  || { err "git worktree add failed"; exit 1; }

# The hook replaces .worktreeinclude processing too — carry gitignored files it names.
inc="$main_root/.worktreeinclude"
if [ -f "$inc" ]; then
  while IFS= read -r pat; do
    case "$pat" in ''|'#'*) continue ;; esac
    ( cd "$main_root" && for f in $pat; do
        [ -f "$f" ] && git check-ignore -q "$f" 2>/dev/null || continue
        mkdir -p "$dir/$(dirname "$f")" && cp -p "$f" "$dir/$f"
      done ) 2>/dev/null
  done <"$inc"
fi

# .workspace/, same as wt: prefer the repo's own initialiser (sibling of this script).
init="$(cd "$(dirname "$0")" && pwd)/ensure-workspace.sh"
[ -x "$init" ] && (cd "$dir" && "$init") >&2

err "created $dir ($branch off $base)"
printf '%s\n' "$dir"
