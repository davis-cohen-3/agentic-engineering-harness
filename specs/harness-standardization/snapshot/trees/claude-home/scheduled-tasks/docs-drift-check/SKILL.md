---
name: docs-drift-check
description: Daily docs-vs-code drift check for melting-v2 — runs the docs-drift skill unattended, files a GitHub issue on real drift.
---

Run the `docs-drift` skill in UNATTENDED mode against the melting v2 code repo.

Repo: /Users/daviscohen/melting/code/melting-v2 (GitHub: melting-co/melting-v2, default branch main).

The skill is the source of truth for the procedure — its full instructions are at
/Users/daviscohen/agents/claude/skills/docs-drift/SKILL.md. Read that file and follow it. In brief:
cd into the repo, `git fetch origin -q`, and look at what changed on origin/main in roughly the last
26 hours. If nothing changed in scope, exit silently — no issue, no output. Otherwise check whether
the repo's docs (CLAUDE.md, agent_docs/**, README, specs/build-week/**) still match the merged code;
keep only concrete, file:line-verifiable drift; explicitly SKIP docs that describe unbuilt/aspirational
work (a spec for code that hasn't shipped is a plan, not drift). If there is real drift, open — or
update, if one is already open — exactly ONE GitHub issue titled "Docs drift: <area>" on
melting-co/melting-v2, each finding as `path:line — doc says X — code shows Y — suggested fix`.

Report-only: never block anything, never edit code, never auto-merge a doc fix. Silent when clean.
Do not run the build, tests, migrations, or make check. This is a bounded daily hygiene pass.