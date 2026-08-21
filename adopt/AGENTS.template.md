# <REPO> — repo profile

This is the repo's PROFILE: its stack, structure, commands, conventions, and tuned hotspots.
It is the **single** profile — Codex reads this file natively and `CLAUDE.md` imports it, so a
fact lives here once and both providers see it. Do not restate any of it in `CLAUDE.md`.

## What this is
<FILL: one or two sentences — what this repo IS and what it's for. The product, not the harness.>

## Stack
<FILL: languages, frameworks, runtime, package manager, datastores. What an agent needs to know
before touching code. In a monorepo, name the sub-projects and where each lives.>

## Structure map
<FILL: the top-level layout — where the important things live. A MAP, not a manual.>
- `<path>` — `<what lives here>`

## Commands
- **Quality gate (defines "done"):** `make check` — runs this repo's real checks (set in
  `make/gate.mk`). Never hand-roll the steps; the gate is the single source of "done".
- **Bootstrap a fresh clone/worktree:** `make setup` — installs deps + provisions env so the
  gate and the app work in a fresh checkout. <FILL: note any manual prerequisite (e.g. `.env`).>
- **Cut a worktree:** `wt <project> --branch <b>` — never raw `git worktree add`. Every
  worktree lives in `<container>/worktrees/`; `wt` (and the WorktreeCreate hook, for
  worktrees Claude cuts itself) puts it there, runs `make setup`, and creates `.workspace/`.
  A relative `git worktree add` from inside a worktree lands somewhere nothing tracks.

## Conventions (enforced here)
<FILL: the few repo-specific conventions that shape how code is written here and aren't already
covered by a linter. Keep to what's broadly load-bearing — anti-bloat applies. A convention
scoped to a file-type/area goes in `.claude/rules/` instead (the `paths:`-scoped lane), not here.>

## Tuned hotspots (this repo)
Touching any of these escalates care regardless of task size. Beyond the convergent base set —
migrations · auth · payments · outbound-send (email/LLM/webhooks) · prod deploy · spend — the
risk surface *here* is:
<FILL: the paths/areas in THIS repo where a mistake is silent or expensive.>
- `<path or area>` — `<why it's a hotspot>`

## Working agreement
- Work on a **task branch**; never commit to the default branch. Ship via PR.
- A change is done only when `make check` passes **and** you ran the change and watched the
  intended behaviour work. Compiling is not working. **Never claim done on unrun code** — the full
  definition is owned by the `verify-before-done` skill.
- Match the surrounding code's structure and idiom. Comment the non-obvious *why*, never the *what*.
- Secrets are never committed. Config references `${VAR}`, never a value.
- **No reviewer runs automatically.** `reviewer` and `reviewer-security` run only when asked for.
