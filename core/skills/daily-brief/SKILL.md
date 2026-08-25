---
name: daily-brief
description: >-
  Reconstruct what the user actually worked on over a given day (or range) from git history,
  every agent worktree (Claude Code, Codex, Conductor, plain git), and GitHub — across every
  repository, not just the current one — then write an honest brief. Reports merged/open/
  abandoned PRs, the narrative threads behind them, and a blunt list of stranded work,
  uncommitted piles, unreviewed risk, and dropped priorities. Use for "brief me on yesterday",
  "what did I work on Aug 18", "catch me up on last week".
argument-hint: "optional: a date (2026-08-18), a range (2026-08-16..18), or nothing for yesterday"
---

# daily-brief

STARTER_CHARACTER = 📓 — open each reply with it while this skill is active.

You are reconstructing a day of engineering work and reporting on it honestly. The deliverable is
a brief the user reads once, in the terminal. It is not a changelog — a list of commit subjects is
a failure.

## Usage

```
/daily-brief                → yesterday
/daily-brief 2026-08-18     → that day
/daily-brief aug 18         → same
/daily-brief 2026-08-16..18 → a range (run the collector per day, write one brief)
```

## Window

**A work day runs `DATE 00:00` → `DATE+1 04:00` local.** Merges at 23:50 and commits at 01:03
belong to the same session. `collect.sh` applies this automatically and tags post-midnight rows
`[POST-MIDNIGHT]`. If any post-midnight work exists, give it its own paragraph — the user asks
about it specifically and it is usually a different kind of work (docs, prototypes, a pivot) than
the daytime bug-fixing.

If the user's date label contradicts itself ("yesterday, Aug 13" when yesterday was the 12th),
**do not block**. Cover the span that satisfies both readings and say so in one sentence at the top.

## Step 1 — collect

```bash
~/.agents/skills/daily-brief/collect.sh <YYYY-MM-DD>
```

It reports across **every repository it can find**, because a day's work is rarely confined to one
checkout. Discovery is: the repo you are standing in, then the project registry at
`${XDG_CONFIG_HOME:-~/.config}/agents/projects.yaml` if it exists, then a shallow scan of the
usual code roots. Narrow it when the user asks for one project — `--this-repo`, or
`--repo <path>` (repeatable). `--roots <dir>` redirects the scan; `--no-fetch` skips the per-repo
fetch when you only need local state; `--no-gh` drops every GitHub call.

Read the whole dump. It is designed to be read once, in full, not grepped. Per repo:

| Section | What it answers |
|---|---|
| `REPO NOTES` | repo-specific context the universal skill cannot know — **treat as authoritative** |
| `WORKTREES` | where agents are putting worktrees, and whether they have sprawled across roots |
| `WORKTREES ACTIVE IN WINDOW` | what was open that day, including branches with no commits |
| `UNCOMMITTED WORK` | work that exists only on disk — the highest-value finding in this whole skill |
| `MY COMMITS IN WINDOW` | committer-dated, local, deduped |
| `…AUTHORED EARLIER BUT COMMITTED IN WINDOW` | rebases; real work, but do not report as new authorship |
| `BRANCHES CARRYING MY IN-WINDOW COMMITS` | catches commits pushed into **someone else's** PR |
| `LOCAL BRANCHES WITH NO REMOTE` | stranded work, with a merge verdict that survives squash-merges |
| `PRS MERGED / CLOSED UNMERGED / OPENED` | the shipped record |
| `MY OPEN PRS` | the backlog; age is the story |
| `REVIEW + BOT HEALTH` | peer reviews vs. self-reviews vs. bots that errored or self-skipped |
| `CHECK STATUS` | CI on open PRs |

Then read the PR bodies for the user's own PRs — `gh pr view <n> --json title,body` — because the
*why* lives there and it is what makes the brief worth reading. Read auto-review threads on
anything large or security-adjacent. Check the state of any issue referenced
(`gh issue view <n>`).

An empty section is a claim. If `PRS CLOSED UNMERGED` is empty, nothing was abandoned; say
nothing. Do not pad.

## Per-repo notes

A repo may carry `.claude/daily-brief.local.md` (or `daily-brief.local.md` at its root) naming its
own conventions: which bot posts reviews, what its branch prefixes mean, which areas are
high-stakes. The collector prints it verbatim and folds any
`<!-- daily-brief: bots = <login>, … -->` line into its bot detection. **Where the notes and this
skill's generic heuristics disagree, the notes win** — they describe a real repo, this file
describes repos in general.

No notes file is the normal case. Never require one, never create one unasked.

## Step 2 — verify before asserting

These are mistakes this skill has actually made. Do not repeat them.

- **A branch that is not an ancestor of the base branch may still have shipped.** Under
  squash-merge — the default on most repos — a merged branch is never an ancestor. The collector's
  verdicts (`LANDED`/`IN-BASE`/`STRANDED`) already account for this; trust them over
  `git merge-base --is-ancestor`, which reports false "unmerged".
- **Use the remote base branch (`origin/…`), never the local one.** The local ref goes stale
  within hours. The collector resolves the real default branch per repo — it is not always `main`.
- **`git log --since/--until` filters committer date; `%ad` prints author date.** The collector
  prints `%cd` for exactly this reason. Never mix them in one table.
- **GitHub timestamps are UTC; `git log` is local.** The collector labels which is which. Convert
  before claiming a time — a 23:40 UTC merge is a 19:40 local merge, a completely different story
  about someone's evening.
- **A self-review is not review.** The collector splits `peerReviews` from `selfReviews`; only
  `peerReviews` answers "did anyone else look at this". Approving your own PR eleven times is a
  record of iteration, not of scrutiny.
- **Zero recorded reviews ≠ nobody reviewed it.** Check the PR comments for the user saying they
  walked it through with someone. Report the gap in the *record*, not an accusation that review
  was skipped.
- **A review bot that errored or self-skipped still leaves a timeline entry that reads like a
  posted review.** Use `botErrored`/`botSkipped`, not the raw comment count.
- **Diff size is not effort.** A 30-line PR that fixes a check-then-create race is a bigger day
  than a 700-line docs commit.

Before writing any factual claim about something *not* landing — a bug still live, a file absent
from the base branch, an issue unfixed — check it directly. `git grep <symbol> origin/main`,
`gh issue view <n> --json state`. One wrong "this never shipped" costs the brief its credibility.

## Step 3 — write

Structure, in this order:

1. **A one-line header.** Counts and the working span: `4 PRs merged, 1 closed unmerged. Worked
   09:36 → 20:52.` If there is post-midnight work, say so here. If more than one repo saw work,
   name them here and nowhere else — the reader needs the shape of the day, not a directory
   listing.
2. **A merged table** — `#`, title, local merge time, `+x/-y`. Add a repo column only when more
   than one repo appears.
3. **Narrative threads**, not a per-PR walkthrough. Group the day into the 2–4 things it was
   actually about, and for each one lead with the *finding* rather than the change: what was
   broken, how it was discovered, why it had gone unnoticed. Name the mechanism. Quote the sharp
   detail (`is_sender` arrives as `0`/`1`, not a boolean; `p + p` invented an 8px gap the design
   doesn't have). Note which agent did what when it matters — branch prefixes usually say, and a
   repo's notes file will explain its own.
4. **"N things"** — a numbered, blunt list, most severe first.

Threads cross repos when the work did. A day spent moving one idea through an app repo and its
harness is **one** thread, not two — organise by what the user was thinking about, never by
directory.

## The "N things" section

This is the part the user actually wants. The standing instruction is: *don't flatter me; give
honest feedback even if I don't want to hear it; push back on mistakes.* A brief that ends on
praise has failed.

Rank by what will cost the most if ignored:

1. Uncommitted work on disk — especially migrations, new services, tests. Give file counts and
   line counts.
2. Stranded branches, and PRs closed unmerged **with no recorded reason** — always name what was
   lost and whether the underlying issue is still open.
3. Large or high-stakes PRs merged, or merging, with no peer review.
4. Work that duplicates something already shipped, or shipped at half its stated scope.
5. Priority items that got a worktree and no commits, or a PR and no merge.
6. Organizational drift: worktree sprawl across roots, naming that no longer matches branches,
   backlog age.

Rules for this section:

- **Every claim carries its evidence.** "19 files, 526 insertions, uncommitted" not "some
  uncommitted work".
- **Track carry-forward.** If an item was flagged in a previous brief, say which day it is on
  ("day 9", "same failure mode I flagged Tuesday") rather than presenting it as news. If it has
  been flagged three times and hasn't moved, say the flagging has stopped being useful and force
  the decision: schedule it or close it.
- **Correct yourself when the evidence changes.** If a previous brief's flag turns out to have
  been too strong, say so in one sentence and move on. Do not re-litigate.
- **Credit what is genuinely good, briefly and specifically, inside the narrative** — a mechanism
  that caught a real bug the day after it shipped is worth one sentence. Never in the flags
  section, never as a closing compliment.
- **Do not invent concern.** If the day was clean, the section is short. Three real things beat
  six padded ones.

## Worktree layout

Agents scatter worktrees: Claude Code, Codex and Conductor each default to their own root, which
is why `collect.sh` enumerates `git worktree list` per repo rather than reading one directory.
Scanning a single root silently drops entire agents' worth of work.

Report the sprawl when it changes: a new root appearing, a typo'd directory, a branch whose
worktree name no longer describes it. Consolidation is the user's call — the brief's job is to
make the cost visible, not to move anything.

## Never

- Never write to any repo. This skill is read-only: no commits, no pushes, no branch deletion, no
  worktree pruning. If a cleanup is obviously warranted, say so and stop.
- Never guess a timestamp, a PR number, or whether something landed.
- Never end with an offer to help. End on the last flag.
