#!/usr/bin/env bash
# SessionStart hook: orient the session to the spec THIS worktree is bound to.
# Resolution order: (1) explicit per-worktree pointer .claude/active-spec, (2) branch-name
# fallback specs/<branch>.md|/ then specs/<last-segment>.md|/. Injects context; NEVER blocks.
# Fails OPEN. Fires on startup|resume|clear|compact, so a session re-anchors after compaction.
# On a (2) hit with no pointer it SELF-BINDS (writes the pointer) so later sessions resolve
# instantly and stay correct across branch renames — the lazy backstop to the eager `make work`
# / orchestrator-at-clone bind. Autonomous runs also get the spec from the dispatch prompt.
set -euo pipefail

command -v git >/dev/null 2>&1 || exit 0   # fail OPEN: no git, no orientation, no harm
root="$(git rev-parse --show-toplevel 2>/dev/null || echo '')"
[ -z "$root" ] && exit 0

spec="" ; note=""

# (1) Explicit per-worktree binding — the exact spec, set when work on it began.
pointer="$root/.claude/active-spec"
if [ -f "$pointer" ]; then
  # `|| true`: an empty/all-whitespace pointer makes grep exit non-zero; without this,
  # `set -e` + pipefail would abort the hook and silently skip the branch-name fallback below.
  want="$(sed -e 's/[[:space:]]*#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$pointer" | grep -v '^$' | head -n1 || true)"
  if [ -n "$want" ]; then
    if [ -e "$root/$want" ]; then
      spec="$want"
    else
      note=".claude/active-spec points at '$want' but it doesn't exist — fix the pointer or the path."
    fi
  fi
fi

# (2) Fallback: infer from the branch name. Try the FULL branch path first (epic/sub-spec
# branches like webhook-retry/02-worker → specs/webhook-retry/02-worker.md), then the last
# segment (type-prefixed branches like feat/rate-limit → specs/rate-limit.md). First hit wins.
from_branch=""
if [ -z "$spec" ] && [ -z "$note" ]; then
  branch="$(git branch --show-current 2>/dev/null || echo '')"
  default="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@' || true)"
  default="${default:-main}"
  case "${branch:-main}" in "$default"|main|master|"") branch="" ;; esac
  if [ -n "$branch" ]; then
    for cand in "$branch" "${branch##*/}"; do
      if [ -f "$root/specs/$cand.md" ]; then spec="specs/$cand.md"; from_branch=1; break
      elif [ -d "$root/specs/$cand" ]; then spec="specs/$cand/"; from_branch=1; break
      fi
    done
  fi
fi

# Self-bind: resolved from the branch with no explicit pointer yet → write one (best-effort).
# Later sessions then resolve via (1) instantly and stay correct even if the branch is renamed.
# Never fail the hook over a write error (read-only FS, etc.).
if [ -n "$from_branch" ] && [ ! -f "$pointer" ]; then
  printf '%s\n' "$spec" > "$pointer" 2>/dev/null || true
fi

# Nothing bound and nothing to warn about (e.g. trivial T0/T1 work) → stay silent, no nag.
[ -z "$spec" ] && [ -z "$note" ] && exit 0

if [ -n "$spec" ]; then
  status=""
  # `|| true`: an unreadable spec file would make sed fail and `set -e` abort the hook —
  # status is optional, so never let it turn a successful orient into a CLOSED (errored) start.
  [ -f "$root/$spec" ] && status="$(sed -n 's/^status:[[:space:]]*\([a-z]*\).*/\1/p' "$root/$spec" | head -n1 || true)"
  slug="$(basename "${spec%/}")" ; slug="${slug%.md}"
  # Scratch notepad: an UNCOMMITTED (gitignored) working buffer for THIS worktree, spanning
  # plan→build→test. Ensure it exists so the path we surface is always real; fail OPEN — a
  # read-only FS must never turn a successful orient into a CLOSED start.
  notepad="specs/.context/$slug.md"
  if [ ! -f "$root/$notepad" ]; then
    mkdir -p "$root/specs/.context" 2>/dev/null \
      && printf '# scratch — %s (gitignored, NOT a source of truth)\n' "$slug" > "$root/$notepad" 2>/dev/null \
      || true
  fi
  msg="Active spec for this worktree: $spec"
  [ -n "$status" ] && msg="$msg (status: $status)"
  msg="$msg. This is the RESOLVED plan — read it before acting. Treat any unresolved design point in it as a hard-stop to flag, not something to invent. Mid-build session handoffs, if any, live under specs/$slug.sessions/; repo-level context is in agent_docs/ (+ ADRs)."
  [ -f "$root/$notepad" ] && msg="$msg Scratch notepad (uncommitted working memory for this worktree, survives compaction): $notepad — read it if non-empty, and append decisions/dead-ends/test results as you go; graduate anything durable into the spec/.thoughts/.sessions, since the notepad is discarded at merge."
else
  msg="$note"
fi

if command -v jq >/dev/null 2>&1; then
  jq -cn --arg ctx "$msg" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}'
else
  printf '%s\n' "$msg"   # fail OPEN: plain stdout is still added to context on SessionStart
fi
exit 0
