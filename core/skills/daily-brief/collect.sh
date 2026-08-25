#!/usr/bin/env bash
# Read-only evidence collector for the daily-brief skill.
#
# Usage: collect.sh [YYYY-MM-DD] [--author RE] [--login LOGIN]
#                   [--repo PATH]... [--roots DIR]... [--this-repo]
#                   [--no-gh] [--no-fetch]
#
# Defaults to yesterday. Window is DATE 00:00 local -> DATE+1 04:00 local, so
# post-midnight work lands in the day it belongs to; rows after midnight are
# tagged [POST-MIDNIGHT].
#
# Reports across EVERY repository it can find, not just the current one, because
# a day's work is rarely confined to one checkout. Discovery order is in
# discover_repos below; --repo/--this-repo pin it explicitly.

set -uo pipefail

DATE=""; AUTHOR=""; LOGIN=""; USE_GH=1; FETCH=1; THIS_ONLY=0
REPOS_ARG=(); ROOTS_ARG=(); BOTS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --author)    AUTHOR="$2"; shift 2 ;;
    --login)     LOGIN="$2";  shift 2 ;;
    --repo)      REPOS_ARG+=("$2"); shift 2 ;;
    --roots)     ROOTS_ARG+=("$2"); shift 2 ;;
    --bot)       BOTS+=("$2"); shift 2 ;;
    --this-repo) THIS_ONLY=1; shift ;;
    --no-gh)     USE_GH=0;    shift ;;
    --no-fetch)  FETCH=0;     shift ;;
    -h|--help)   sed -n '2,16p' "$0"; exit 0 ;;
    -*)          echo "unknown arg: $1" >&2; exit 2 ;;
    *)           DATE="$1"; shift ;;
  esac
done

# BSD and GNU date disagree on every flag that matters here, so each call needs
# both spellings. Getting this wrong yields a silently empty window, not an error.
day_offset() { date -j -v"$2"d -f %Y-%m-%d "$1" +%Y-%m-%d 2>/dev/null || date -d "$1 $2 day" +%Y-%m-%d; }
[ -z "$DATE" ] && DATE="$(day_offset "$(date +%Y-%m-%d)" -1)"
case "$DATE" in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;; *) echo "date must be YYYY-MM-DD, got: $DATE" >&2; exit 2 ;; esac

NEXT="$(day_offset "$DATE" +1)"
SINCE="$DATE 00:00:00"; UNTIL="$NEXT 04:00:00"
# gh reports UTC only; comparing it against a local timestamp is silently wrong
# and yields empty sections rather than an error. Go via epoch: BSD date ignores
# the output format when -u follows the input, so -u must not be mixed with -f.
to_utc() {
  local e
  e="$(date -j -f '%Y-%m-%d %H:%M:%S' "$1" +%s 2>/dev/null)" || { date -u -d "$1" +%Y-%m-%dT%H:%M:%SZ; return; }
  date -u -r "$e" +%Y-%m-%dT%H:%M:%SZ
}
SINCE_UTC="$(to_utc "$SINCE")"; UNTIL_UTC="$(to_utc "$UNTIL")"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
say()  { printf '%s\n' "$*"; }
sec()  { printf '\n--- %s\n' "$1"; }
tilde() { echo "$1" | sed "s|^$HOME|~|"; }
expand_tilde() { case "$1" in "~"/*) echo "$HOME/${1#\~/}" ;; "~") echo "$HOME" ;; *) echo "$1" ;; esac; }

# The main worktree is a repo's identity: two candidate paths that share one are
# the same repo seen twice (a worktree and its checkout), and must not both be
# scanned — worktrees are enumerated per-repo below.
canon() { git -C "$1" worktree list --porcelain 2>/dev/null | awk 'NR==1{print substr($0,10); exit}'; }

# ---------------------------------------------------------------- discovery
# Order: explicit flags > the harness project registry > a shallow scan of
# common code roots. The registry is a convenience, never a requirement — the
# scan is what makes this correct in a repo and on a machine it has never seen.
registry_repos() {
  local reg="${XDG_CONFIG_HOME:-$HOME/.config}/agents/projects.yaml"
  [ -f "$reg" ] || return 0
  awk '/^projects:/{p=1;next} p&&/^[^[:space:]#]/{p=0} p&&/^[[:space:]]+repo:[[:space:]]*/{sub(/^[[:space:]]+repo:[[:space:]]*/,"");print}' "$reg"
}
scan_roots() {
  local roots=("$@") r
  [ "${#roots[@]}" -eq 0 ] && roots=("$HOME/dev" "$HOME/code" "$HOME/src" "$HOME/projects" "$HOME/repos" "$HOME/Documents/GitHub")
  for r in "${roots[@]}"; do
    r="$(expand_tilde "$r")"; [ -d "$r" ] || continue
    find "$r" -maxdepth 4 -name .git -not -path '*/node_modules/*' 2>/dev/null | sed 's|/\.git$||'
  done
}
discover_repos() {
  local here; here="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ "$THIS_ONLY" = "1" ]; then [ -n "$here" ] && canon "$here"; return; fi
  if [ "${#REPOS_ARG[@]}" -gt 0 ]; then
    local p; for p in "${REPOS_ARG[@]}"; do p="$(expand_tilde "$p")"; canon "$p"; done; return
  fi
  { [ -n "$here" ] && canon "$here"
    registry_repos | while read -r p; do p="$(expand_tilde "$p")"; [ -d "$p" ] && canon "$p"; done
    scan_roots "${ROOTS_ARG[@]+"${ROOTS_ARG[@]}"}" | while read -r p; do canon "$p"; done
  }
}
# Preserve discovery order (the repo you are standing in first) while deduping.
# read -a, not mapfile: macOS still ships bash 3.2, where mapfile does not exist.
REPOS=()
while IFS= read -r l; do REPOS+=("$l"); done < <(discover_repos | awk 'NF && !seen[$0]++')

[ "${#REPOS[@]}" -eq 0 ] && { echo "no git repositories found (try --repo PATH or --roots DIR)" >&2; exit 2; }

[ "$USE_GH" = "1" ] && [ -z "$LOGIN" ] && LOGIN="$(gh api user --jq .login 2>/dev/null || true)"

say "window=$SINCE -> $UNTIL (local $(date +%z))  |  utc=$SINCE_UTC -> $UNTIL_UTC"
say "login=${LOGIN:-n/a}  (all dates below are COMMITTER dates in local time unless marked UTC)"
say "repos scanned (${#REPOS[@]}):"
for r in "${REPOS[@]}"; do say "  $(tilde "$r")"; done

# ---------------------------------------------------------------- per repo
# git log --since/--until filter on COMMITTER date, so display %cd to match.
# A commit authored earlier but committed in-window is real in-window work (a
# rebase or a cherry-pick), and must not be silently dropped or mislabelled.
FMT='%cd|%h|%an|%d|%s'
rx() { printf '%s' "$1" | sed 's/[][\.^$*+?(){}|\\]/\\&/g'; }

for REPO in "${REPOS[@]}"; do
  [ -d "$REPO" ] || continue
  cd "$REPO" || continue
  printf '\n\n========== REPO %s ==========\n' "$(tilde "$REPO")"

  # Per repo, because identity is per repo: the same person is davis-cohen-3 in
  # one checkout and Davis Cohen in another. A global --author overrides both.
  a="$AUTHOR"
  if [ -z "$a" ]; then
    n="$(git config user.name || true)"; e="$(git config user.email || true)"
    a="$(rx "${n:-$USER}")"; [ -n "$e" ] && a="$a|$(rx "$e")"
  fi
  say "author=/$a/"

  [ "$FETCH" = "1" ] && git fetch -q origin 2>/dev/null

  # Not every repo's default branch is main, and a repo with no remote has none.
  BASE="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [ -z "$BASE" ]; then
    for c in origin/main origin/master origin/trunk; do
      git rev-parse --verify -q "$c" >/dev/null 2>&1 && { BASE="$c"; break; }
    done
  fi
  say "base=${BASE:-<none — no remote tracking branch; merge verdicts unavailable>}"

  # gh only answers for GitHub remotes; anywhere else its errors are noise.
  GH=0
  if [ "$USE_GH" = "1" ] && git remote get-url origin 2>/dev/null | grep -qi 'github\.com'; then GH=1; fi
  say "github=$([ "$GH" = "1" ] && echo yes || echo 'no (gh sections skipped for this repo)')"

  # Per-repo quirks the universal skill cannot know: which bot posts reviews,
  # what the branch prefixes mean, which work matters. Optional by design.
  NOTES=""
  for c in "$REPO/.claude/daily-brief.local.md" "$REPO/daily-brief.local.md"; do
    [ -f "$c" ] && { NOTES="$c"; break; }
  done
  if [ -n "$NOTES" ]; then sec "REPO NOTES ($(tilde "$NOTES")) — repo-specific context, treat as authoritative"; cat "$NOTES"; fi

  # A review bot with an ordinary-looking login is invisible to the generic
  # pattern below and inflates the human-review count — the one number the
  # brief's central flag depends on. A repo names its own bots in its notes
  # file with a line like:  <!-- daily-brief: bots = shape-face, my-linter -->
  BOT_RE='bot|\[bot\]|-ai$'
  extra=""
  [ -n "$NOTES" ] && extra="$(sed -n 's/.*daily-brief:[[:space:]]*bots[[:space:]]*=[[:space:]]*//p' "$NOTES" | tr ',' ' ')"
  for b in $extra ${BOTS[@]+"${BOTS[@]}"}; do
    b="$(rx "$b")"; [ -n "$b" ] && BOT_RE="$BOT_RE|^$b\$"
  done

  if [ "$GH" = "1" ]; then
    gh pr list --state all --limit 400 \
      --json number,title,author,createdAt,closedAt,mergedAt,additions,deletions,headRefName,isDraft,reviewDecision \
      > "$TMP/prs.json" 2>/dev/null || echo '[]' > "$TMP/prs.json"
    jq -r '.[] | "\(.headRefName)|\(.number)|\(if .mergedAt then "MERGED" elif .closedAt then "CLOSED" else "OPEN" end)"' \
      "$TMP/prs.json" > "$TMP/heads.txt" 2>/dev/null || : > "$TMP/heads.txt"
  else
    echo '[]' > "$TMP/prs.json"; : > "$TMP/heads.txt"
  fi

  worktrees() { git worktree list --porcelain | awk '/^worktree /{print substr($0,10)}'; }

  # ------------------------------------------------------------ worktrees
  sec "WORKTREES"
  # Registered worktrees are authoritative. Each agent (Claude Code, Codex,
  # Conductor, plain git) creates them under its own root, so scanning one
  # directory misses whole agents' worth of work.
  #
  # Some tools nest the checkout one level down (<root>/<slug>/<repo-name>), so
  # a plain dirname invents a separate root per slug. Strip a trailing copy of
  # the repo's own directory name first, and leave the main worktree out — it is
  # the repo, not a root.
  BN="$(basename "$REPO")"
  worktrees | tail -n +2 | while read -r w; do w="${w%/$BN}"; dirname "$w"; done \
    | sed "s|^$HOME|~|" | sort | uniq -c | sort -rn | sed 's/^/  count-by-root: /'
  nroots=$(worktrees | tail -n +2 | while read -r w; do w="${w%/$BN}"; dirname "$w"; done | sort -u | wc -l | tr -d ' ')
  [ "$nroots" -gt 1 ] && say "  ^ $nroots distinct roots — worktree sprawl; report it when it changes"
  worktrees | while read -r w; do
    printf '  %-72s %s\n' "$(tilde "$w")" "$(git -C "$w" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  done

  sec "WORKTREES ACTIVE IN WINDOW"
  # Root-dir mtime alone is weak (it only moves when a direct child changes), so
  # take the max of the root mtime and the git index mtime, which any checkout,
  # add, stash or status bumps.
  worktrees | while read -r w; do
    [ -d "$w" ] || continue
    gd="$(git -C "$w" rev-parse --git-dir 2>/dev/null)"
    best=""
    for p in "$w" "$gd/index"; do
      [ -e "$p" ] || continue
      m=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$p" 2>/dev/null || stat -c '%y' "$p" 2>/dev/null | cut -c1-16)
      [[ "$m" > "$best" ]] && best="$m"
    done
    [ -z "$best" ] && continue
    if [[ "$best" > "$SINCE" && "$best" < "$UNTIL" ]]; then
      echo "  $best | $(git -C "$w" rev-parse --abbrev-ref HEAD 2>/dev/null) | $(tilde "$w")"
    fi
  done | sort

  sec "UNCOMMITTED WORK (every worktree, any age — this is what silently disappears)"
  worktrees | while read -r w; do
    [ -d "$w" ] || continue
    n=$(git -C "$w" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    [ "$n" = "0" ] && continue
    echo "  --- $(tilde "$w") [$(git -C "$w" rev-parse --abbrev-ref HEAD 2>/dev/null)] $n entries; tracked:$(git -C "$w" diff --shortstat 2>/dev/null | sed 's/^ *//')"
    git -C "$w" status --short 2>/dev/null | head -25 | sed 's/^/    /'
    git -C "$w" ls-files --others --exclude-standard 2>/dev/null \
      | while read -r f; do [ -f "$w/$f" ] && echo "      untracked $(wc -l < "$w/$f" | tr -d ' ')L  $f"; done | head -25
  done

  # -------------------------------------------------------------- commits
  sec "MY COMMITS IN WINDOW"
  git log --all --no-merges -E --regexp-ignore-case --author="$a" \
    --since="$SINCE" --until="$UNTIL" --date=iso-local --pretty="$FMT" \
    | sort -u -t'|' -k2 | sort | awk -F'|' -v d="$NEXT" '{print "  " $0 ($1 ~ "^"d ? "  [POST-MIDNIGHT]" : "")}'

  sec "MY COMMITS AUTHORED EARLIER BUT COMMITTED IN WINDOW (rebases/cherry-picks)"
  git log --all --no-merges -E --regexp-ignore-case --author="$a" \
    --since="$SINCE" --until="$UNTIL" --date=iso-local --pretty='%cd|%ad|%h|%s' \
    | awk -F'|' '{ if (substr($1,1,10) != substr($2,1,10)) print "  committed "$1" but authored "$2" | "$3" "$4 }' | sort -u

  sec "BRANCHES CARRYING MY IN-WINDOW COMMITS (catches work pushed into someone else's PR)"
  git log --all --no-merges -E --regexp-ignore-case --author="$a" \
    --since="$SINCE" --until="$UNTIL" --pretty='%H' \
    | while read -r c; do git branch -a --contains "$c" 2>/dev/null; done \
    | sed 's/^[* ]*//' | sort | uniq -c | sort -rn | sed 's/^/  /'

  sec "EVERYONE ELSE'S COMMITS IN WINDOW (team context only)"
  git log --all --no-merges --since="$SINCE" --until="$UNTIL" --date=iso-local --pretty='%cd|%an|%s' \
    | grep -viE "\|[^|]*($a)[^|]*\|" | sort -u | awk -F'|' '{print "  "$1"  "$2": "$3}' | head -60

  # --------------------------------------------------------------- strays
  sec "LOCAL BRANCHES WITH NO REMOTE (stranded-work check)"
  # Ancestry is NOT merge status: a squash-merged branch is never an ancestor of
  # the base. Verdicts, most to least trustworthy:
  #   LANDED   — GitHub says a PR with this head merged
  #   IN-BASE  — full tree diff vs the base branch is empty
  #   ORPHANED — a PR with this head was closed unmerged
  #   nothing-unshipped — no commits on it the base lacks
  #   STRANDED — real unshipped commits, no PR. These are the ones to report.
  git for-each-ref --format='%(refname:short)|%(committerdate:iso8601-local)' refs/heads \
    | sort -t'|' -k2 -r | while IFS='|' read -r b when; do
    git rev-parse --verify -q "origin/$b" >/dev/null && continue
    if [ -n "$BASE" ]; then n=$(git rev-list --count "$BASE..$b" 2>/dev/null || echo '?'); else n='?'; fi
    pr="$(grep -m1 "^${b}|" "$TMP/heads.txt" 2>/dev/null || true)"
    if   [ -n "$pr" ] && [ "${pr##*|}" = "MERGED" ]; then v="LANDED (#$(echo "$pr" | cut -d'|' -f2))"
    elif [ "$n" = "0" ];                             then v="nothing-unshipped"
    elif [ -n "$BASE" ] && [ -z "$(git diff "$BASE" "$b" --stat 2>/dev/null)" ]; then v="IN-BASE"
    elif [ -n "$pr" ] && [ "${pr##*|}" = "CLOSED" ]; then v="ORPHANED (#$(echo "$pr" | cut -d'|' -f2) closed unmerged)"
    elif [ -n "$pr" ];                               then v="open PR #$(echo "$pr" | cut -d'|' -f2)"
    else v="STRANDED"; fi
    printf '  %s | %-46s | ahead=%-3s | %s\n' "${when:0:16}" "$b" "$n" "$v"
  done

  # --------------------------------------------------------------- github
  [ "$GH" = "1" ] || continue

  sec "PRS MERGED IN WINDOW (UTC)"
  jq -r --arg a "$SINCE_UTC" --arg b "$UNTIL_UTC" '.[] | select(.mergedAt != null and .mergedAt >= $a and .mergedAt < $b)
    | "  \(.mergedAt)|#\(.number)|\(.author.login)|+\(.additions)/-\(.deletions)|\(.headRefName)|\(.title)"' "$TMP/prs.json" | sort

  sec "PRS CLOSED UNMERGED IN WINDOW (abandoned — never report these without a reason)"
  jq -r --arg a "$SINCE_UTC" --arg b "$UNTIL_UTC" '.[] | select(.mergedAt == null and .closedAt != null and .closedAt >= $a and .closedAt < $b)
    | "  \(.closedAt)|#\(.number)|\(.author.login)|\(.headRefName)|\(.title)"' "$TMP/prs.json" | sort

  sec "PRS OPENED IN WINDOW"
  jq -r --arg a "$SINCE_UTC" --arg b "$UNTIL_UTC" '.[] | select(.createdAt >= $a and .createdAt < $b)
    | "  \(.createdAt)|#\(.number)|\(.author.login)|draft=\(.isDraft)|\(.headRefName)|\(.title)"' "$TMP/prs.json" | sort

  sec "MY OPEN PRS (backlog — age is the story)"
  # Queried directly, not filtered out of prs.json: the recency-ordered 400-PR
  # window silently drops the oldest open PRs, which are exactly the ones worth
  # reporting. Blank reviewDecision means requested-but-none, not null.
  # Two gh traps here. (1) --author combined with a multi-field --json routes gh
  # through the search API, which rejects reviewDecision with a bare "invalid
  # character" error, so filter by author in jq instead. (2) gh's embedded jq
  # rejects if/then/else inside string interpolation, so pipe to real jq.
  gh pr list --state open --limit 300 \
    --json number,title,author,createdAt,additions,deletions,headRefName,isDraft,reviewDecision 2>/dev/null \
    | jq -r --arg me "$LOGIN" '.[] | select(.author.login == $me)
        | "\(.createdAt)|#\(.number)|draft=\(.isDraft)|+\(.additions)/-\(.deletions)|review=\(if (.reviewDecision // "") == "" then "NONE" else .reviewDecision end)|\(.headRefName)|\(.title)"' \
    > "$TMP/open.txt" 2>/dev/null
  sort "$TMP/open.txt" | sed 's/^/  /'
  say "  -> $(wc -l < "$TMP/open.txt" | tr -d ' ') open, oldest $(sort "$TMP/open.txt" | head -1 | cut -c1-10)"

  sec "REVIEW + BOT HEALTH ON MY PRS TOUCHED IN WINDOW"
  # A review bot that errored or self-skipped still leaves a timeline entry that
  # reads like a posted review, so count the outcomes rather than the entries.
  # Bot identity is matched generically; name yours in the repo notes file.
  jq -r --arg me "$LOGIN" --arg a "$SINCE_UTC" --arg b "$UNTIL_UTC" '.[]
    | select(.author.login == $me)
    | select((.mergedAt == null and .closedAt == null) or (.mergedAt >= $a and .mergedAt < $b) or (.closedAt >= $a and .closedAt < $b))
    | .number' "$TMP/prs.json" | while read -r n; do
    gh pr view "$n" --json number,reviews,comments 2>/dev/null \
      | jq -r --arg me "$LOGIN" --arg bots "$BOT_RE" '
          (.reviews // []) as $r
          | ($r | map(select(.author.login | test($bots;"i")))         | length) as $bot
          | ($r | map(select((.author.login | test($bots;"i")) | not)) | length) as $hum
          | ($r | map(select(.author.login == $me))                    | length) as $self
          | "  #\(.number) peerReviews=\($hum - $self) selfReviews=\($self) botReviews=\($bot) botErrored=\([(.comments//[])[]|select(.body|test("encountered an error";"i"))]|length) botSkipped=\([(.comments//[])[]|select(.body|test("skipping .{0,30}(auto-)?review";"i"))]|length) comments=\((.comments//[])|length)"'
  done

  sec "CHECK STATUS ON MY OPEN PRS"
  # gh pr view --json statusCheckRollup returns null check names on some repos;
  # gh pr checks is the reliable read.
  cut -d'|' -f2 "$TMP/open.txt" | tr -d '#' | while read -r n; do
    # gh pr checks emits TAB-separated NAME/STATUS/ELAPSED/URL; splitting on
    # spaces mangles any check whose name contains one ("Test (Integration)").
    out="$(gh pr checks "$n" 2>/dev/null | awk -F'\t' 'tolower($2)!="skipping"{print $2}' | sort | uniq -c | tr '\n' ' ')"
    echo "  #$n  ${out:-no checks}"
  done
done
