---
description: Run the quality gate and open a PR for the finished task
argument-hint: [what reviewers should focus on]
---

You are shipping the current task as a pull request.

Current repository state (read before doing anything):
- Branch & changes: !`git status --short --branch`
- Recent commits: !`git log --oneline -5`

If there are unexpected uncommitted changes or you are on the default branch,
STOP and tell me before proceeding.

Otherwise, follow the **open-a-pr** skill exactly (quality gate → description →
open). The single source of truth for the procedure is that skill — do not
reinvent the steps here.

Reviewer focus for the PR description: $ARGUMENTS

## Close out `MISSION.md`

Before opening the PR, write the final position into `.workspace/MISSION.md` and set
`state: shipped`. You are the owner of this write (CONTRACT §2).

`abandoned` is set only by an explicit close, never automatically.

**Carry the settled decisions from `.workspace/LOG.md` into the PR body.** The worktree — and
`LOG.md` with it — may be gone by merge time, and the PR body is the only thing that survives it.
Nothing checks that this happened.
