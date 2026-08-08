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
