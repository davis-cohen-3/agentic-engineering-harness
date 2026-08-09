> ## ⚠ SUPERSEDED — DO NOT EXECUTE
>
> Deletes the Makefile and omits the required per-file docs merge, the workspace-doc rewrite, and the nested-worktree cleanup. Replaced by task T2.3.
>
> **Authority:** `DECISIONS-PENDING.md` → `CONTRACT.md` →
> `HARNESS-DEPOT-OPERATIONAL-DESIGN-REVIEW.md` → `plan/tasks.md`.
> Retained as provenance and research. Harvest evidence from it; do not run its instructions.
>
> *Bannered 2026-08-08.*

---
status: superseded
tier: T3
hotspots: []
---

# 06 · Migrate melting-v2 (the proving ground)

> Part of the [harness standardization](./README.md) epic — read its **Shared context** and
> **Epic-level decisions** first.

## Goal
Migrate `melting/code/melting-v2` to the new shape and, in doing so, establish the repeatable
recipe that tasks 07 and 08 follow. melting-v2 goes first because it is **already closest to the
target** — the risk of discovering the recipe is wrong is lowest here, and what is learned is
cheapest to apply.

Ships as a PR against the melting-v2 repository, not this one.

## Approach (resolved at the epic level — execute, don't re-decide)

### Why this repo first — what it already gets right
- `CLAUDE.md` is **already the adapter**: `# Claude Code adapter — Melting v2`, then `@AGENTS.md`,
  then Claude-specific routing. This is the target model, working today. It needs no restructuring.
- `make/gate.mk` is honest about being a pass-through: *"Each step delegates to the root npm script
  so there is ONE source of truth."* Every arm is `npm run <x>`.
- It already separates the expensive tier: a `verify:` target running `npm run test:pg`, commented
  *"DB-backed test tier (NOT in the gate) — what verify-before-done runs for DB-backed tasks."*
  That is this epic's thesis, already implemented locally.

So the migration is mostly **deletion**, plus relocating three facts the Makefile was holding.

### The recipe (this is what 07 and 08 will reuse)
1. **Lift the commands out of `gate.mk` into `AGENTS.md` as prose**, preserving what the Makefile
   encoded that a bare list would lose:
   - the **ordering constraint** — `build` must precede `typecheck` because `api`/`web` resolve
     `@melting/schema` from its built `dist`. This is exactly the kind of non-obvious fact
     `AGENTS.md` is for; it must survive the move, stated as a sentence, not implied by list order.
   - the **scope note** — the local set is the fast no-database tier; CI additionally runs the
     migration dry-run against a Postgres service container and the Python scraper import check
     (`.github/workflows/ci.yml`). Keep this; it prevents "the checks passed" meaning more than it does.
   - **bootstrap** — `npm ci`, as a prose line.
2. **`verify: npm run test:pg` becomes the `/e2e` skill's target** for this repo, with its
   `TEST_PG_URL` prerequisite (default `postgres://localhost:5432/postgres`, Postgres 16 + pgvector).
   It was never part of the gate; now it is explicitly opt-in, which is what its own comment always
   said it was.
3. **Delete** `Makefile` and `make/`. Check `.github/workflows/` first — if CI invokes `make check`,
   it changes to the npm scripts directly, in the same PR. A migration that greens the repo and
   reds CI is not done.
4. **Fill `.claude/hooks/lint-edited-file.sh`** with this repo's single-file linters. Establish the
   real per-file invocations (likely `npx eslint --fix <file>` and `npx prettier --write <file>`);
   confirm each actually accepts a single path in this repo's config before wiring it.
5. **Per-area `AGENTS.md`** for `apps/`, `packages/`, `services/`, `ops/` — only where an area has
   commands or conventions that genuinely differ from the root. Do not create a file per directory
   as a matter of form; an area file that only restates the root is pure cost. Commands and local
   conventions only — never a safety-critical rule (subdirectory files don't survive `/compact`).
   The Python scraper under `services/` is the strongest candidate: a different toolchain entirely.
6. **Refresh `.claude/` from the base** (skills, agents, hooks, commands) so this repo carries the
   post-01/02/03 versions. It has no `FLOOR.md` to delete — it never had one, which is itself part
   of the drift this epic closes.
7. **Reconcile `.codex/`** against `.claude/` — see task 07 for the full treatment; here, confirm
   whether melting-v2's `.codex/` has diverged and bring it in line.

## Task decomposition
1. Audit `.github/workflows/` for `make` invocations; note every one — deps: none
2. Lift commands + ordering constraint + scope note + bootstrap into `AGENTS.md` — deps: #1
3. Move `verify: npm run test:pg` + its Postgres prerequisite into the `/e2e` skill's targets — deps: #2
4. Delete `Makefile` + `make/`; update CI to call the npm scripts directly — deps: #2, #3
5. Fill `lint-edited-file.sh` with verified single-file linter invocations — deps: none
6. Add per-area `AGENTS.md` only where an area genuinely differs — deps: #2
7. Refresh `.claude/` from the base; reconcile `.codex/` — deps: none

## Acceptance criteria
- [ ] #2: `AGENTS.md` states the build-before-typecheck constraint **and why** (schema `dist`
      resolution) in prose — not merely as list order
- [ ] #2: `AGENTS.md` states that the local set omits the migration dry-run and the Python scraper
      import check, and that CI runs those
- [ ] #4: `rg -n "make check|make/gate|GATE_STEPS" .github/ AGENTS.md CLAUDE.md` returns nothing
- [ ] #4: CI passes on the PR — the actual proof that step 4 is complete
- [ ] #4: every command named in `AGENTS.md` runs green from a clean `npm ci`
- [ ] #5: editing one `.ts` file with a deliberate lint error surfaces that error in-session;
      editing a `.md` file does nothing
- [ ] #5: the lint hook's runtime on a single real file is under one second, measured
- [ ] #6: each per-area `AGENTS.md` created contains at least one fact not in the root file
- [ ] #7: `diff -rq .claude/skills .codex/…` (whatever the mirror layout is) shows no unexplained
      divergence
- [ ] `CLAUDE.md` still loads `AGENTS.md` and its Claude-specific routing section is preserved

## Out of scope
- Any change to melting-v2's application code, tests, or npm scripts. If a command named in
  `AGENTS.md` is currently broken, record it in the PR description — do not fix it here.
- The separate `melting-v2-spec` repository (product architecture + numbered decisions).
- `melting/code/v1` — handled in task 08's sweep.

## Risk hotspots touched
- **prod deploy** if `.github/workflows/` changes touch a deploy job rather than only CI checks.
  Read every workflow before editing; if a deploy path is involved, engage `reviewer-security`.
- The ordering constraint (#2) is the highest-value fact in this migration and the easiest to lose.
  Losing it produces typecheck failures that look like real type errors and waste a whole session.

## Context pointers
- `make/gate.mk` — read it in full before deleting; its comments hold the three facts to rescue
- `CLAUDE.md` — already correct; the model to preserve, not to change
- `.github/workflows/ci.yml` — the two extra CI-only jobs referenced in the gate's scope note
- `package.json` — the npm scripts the gate delegates to
- `.claude/skills/e2e/SKILL.md` — from task 03; the targets block to fill

## Verification
- checks: every command now named in `AGENTS.md`, run from a clean `npm ci` — reported with output
- manual: make a one-line change in `apps/`, confirm the lint hook fires on that file only; run
  `/e2e` and confirm it uses `npm run test:pg` against a real Postgres; start a fresh session and
  confirm `/context` shows `CLAUDE.md` → `AGENTS.md` and, when a `services/` file is read, that
  area's file loading on demand (`verify-before-done`)
- CI green on the PR
