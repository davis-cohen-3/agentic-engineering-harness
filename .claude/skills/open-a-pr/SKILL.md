---
name: open-a-pr
description: >-
  Use when a task is finished and you're ready to ship it as a pull request.
  Covers branch hygiene, running the quality gate before opening, and writing
  a reviewable PR description. Trigger on "open a PR", "ship this", "raise a PR".
---

# Open a pull request

STARTER_CHARACTER = 🚢 — open each reply with it while this skill is active.

Follow this when the user asks to ship finished work. The goal: a PR a human can
review for **logic, not formatting** — because the harness already handled the rest.

## 1. Pre-flight (do not skip)
- Confirm you are on a task branch, NOT the default branch. If not, create one.
- Run the quality gate: `make check`. **Do not open a PR until it passes.**
  If it fails, fix or report — never open a red PR silently.

## 2. Write the description
Use the template at `pr-description.md` (in this skill folder) as the structure.
Fill every section. Keep the "Why" above the "What" — reviewers need intent first.

**Carry the settled decisions from `.workspace/LOG.md` into the `## Decisions` section** —
read the file and transcribe its `DECISION` entries, including what was rejected and why.
The worktree, and `LOG.md` with it, may be gone by merge time: a retention sweep can remove a
worktree nobody retired. The PR body is the only bridge, and **nothing checks that you did this**.
If `LOG.md` does not exist or holds no decisions, drop the section rather than inventing content.

## 3. Open it
- Push the branch, open the PR with `gh pr create`.
- Title: imperative and specific ("Add retry to webhook sender", not "fixes").
- Paste the filled template as the body.

## 4. Hand back
Report the PR URL and a one-line summary of what reviewers should focus on.
