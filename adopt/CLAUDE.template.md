# <REPO> — repo profile

> Two parts: the **PROFILE** below (this repo's stack, structure, commands, conventions, tuned
> hotspots) and the **FLOOR** — the repo-agnostic must-always-fire rules, imported just below
> from `.claude/FLOOR.md`, inherited byte-identical and never edited per repo. The `adopt-harness`
> skill generates this PROFILE and ships the FLOOR untouched.

@.claude/FLOOR.md

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

## Conventions (enforced here)
<FILL: the few repo-specific conventions that shape how code is written here and aren't already
covered by the FLOOR or a linter. Keep to what's broadly load-bearing — anti-bloat applies.
A convention scoped to a file-type/area goes in `.claude/rules/` instead (the `paths:`-scoped
lane; see `migrations.md`), not here.>

## Tuned hotspots (this repo)
Beyond the base set in the FLOOR (migrations · auth · payments · outbound-send · prod deploy ·
spend), the risk surface *here* is:
<FILL: the paths/areas in THIS repo where a mistake is silent or expensive. Engage
`reviewer-security` when touching them.>
- `<path or area>` — `<why it's a hotspot>`
