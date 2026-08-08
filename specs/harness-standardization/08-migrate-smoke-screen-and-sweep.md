> ## ⚠ SUPERSEDED — DO NOT EXECUTE
>
> Deletes the Makefile and combines a Smoke migration with an unsequenced machine sweep. Split into task T2.2 and Wave 1.
>
> **Authority:** `DECISIONS-PENDING.md` → `CONTRACT.md` →
> `docs/HARNESS-DEPOT-OPERATIONAL-DESIGN-REVIEW.md` → `plan/tasks.md`.
> Retained as provenance and research. Harvest evidence from it; do not run its instructions.
>
> *Bannered 2026-08-08.*

---
status: superseded
tier: T3
hotspots: []
---

# 08 · Migrate smoke-screen + sweep the stragglers

> Part of the [harness standardization](./README.md) epic — read its **Shared context** and
> **Epic-level decisions** first. Apply the recipe from [task 06](./06-migrate-melting.md).

## Goal
Migrate the last full repo, then close out the machine: confirm nothing on disk still carries the
old shape, and record the result. This is the run that makes the epic's claim checkable.

Ships as **two** PRs — one against smoke-screen, one against this repo for the closing audit —
plus non-repo cleanup.

## Approach (resolved at the epic level — execute, don't re-decide)

### Part A — smoke-screen
The most interesting migration, because it is **half-migrated already, ad hoc**:
- It ships per-directory `CLAUDE.md` in `apps/smoke-web`, `apps/smoke-admin` and `services/api` —
  working prior art for the target model, adopted without the harness knowing.
- Its `CLAUDE.md` and `AGENTS.md` **reference each other circularly**: `AGENTS.md` says "See
  `CLAUDE.md` for full project structure, commands, and conventions"; `CLAUDE.md` says "See
  `AGENTS.md` and `.claude/rules/worktree-setup.md` for the full policy." Content overlaps in both.
- Its `make/gate.mk` is the epic's headline exhibit — its own comment reads *"Steps delegate to the
  repo's real npm scripts so the gate never drifts from CI,"* and the body is `lint: npm run lint`,
  `build: npm run build`, `test: npm run test`.

Migration:
1. **Break the circularity.** `AGENTS.md` absorbs the shared content and becomes the source;
   `CLAUDE.md` becomes `@AGENTS.md` + Claude-only routing. The worktree policy — currently split
   across both files and `.claude/rules/worktree-setup.md` — lands in **one** place. It belongs in
   the root `AGENTS.md`, not a subdirectory file: it is safety-critical (a wrong `.env` symlink
   crashes vite with `ELOOP`; working in the main checkout is forbidden) and must survive `/compact`.
2. **`.claude/rules/worktree-setup.md`** → merged into the root `AGENTS.md` per epic decision 3.
   `.claude/rules/` is then empty and removed.
3. **Lift the commands.** `npm run lint`, `npm run build`, `npm run test` into `AGENTS.md`, keeping
   the two facts `gate.mk` encoded: **`build` IS the typecheck** (it runs `tsc` across every
   workspace, so there is no separate typecheck step) and **there is no repo-wide formatter**.
   Both are the kind of "why isn't there an X step" question that costs a session if lost.
   Bootstrap: `npm ci`, plus `bash scripts/link-worktree-env.sh` for the `.env` symlinks.
4. **Delete** `Makefile` + `make/`; update `.github/workflows/` if it calls `make`.
5. **Convert the three existing per-directory `CLAUDE.md` files to `AGENTS.md`**, each with a
   one-line `CLAUDE.md` (`@AGENTS.md`) beside it — so Codex sees them too, which it currently does
   not. Consider whether `packages/schema`, `packages/components` and `services/datadog-agent` also
   warrant one; create only where there is a fact not already in the root.
6. **Fill `lint-edited-file.sh`** with the single-file TS invocation; verify it works against this
   repo's eslint config from the root of a workspace monorepo (a common failure point — eslint
   resolving the wrong config for a file in a workspace).
7. **Refresh `.claude/`** from the base; reconcile `.codex/`. Note smoke-screen has **no**
   `FLOOR.md` at root while its worktrees under `workspaces/smoke-screen/*` **do** — those
   worktrees are on older branches and will resolve themselves on rebase.

### Part B — the sweep
Confirm and close, in this order:
- **`melting/code/v1`** — `.claude/` and `CLAUDE.md`, no Makefile, no FLOOR. Determine whether it
  is still live. If dormant, leave it and record that; if live, apply the recipe. **Ask before
  migrating** — a dormant repo is not worth a PR.
- **`dev/life-os`** — `.claude/` but no `CLAUDE.md`, no git, no Makefile. Contents are planning
  documents (`life-os-build-spec.md`, `life-os-prd.md`, …), not code. Give it a plain `AGENTS.md`
  only if that helps; it is not an adopted repo and should not become one by default.
- **`opt/depot`** — a worktree of depot. Confirm it inherits task 07's changes on rebase. No action.
- **`dev/archive/*`** — five repos with `CLAUDE.md`, archived. **No action, explicitly recorded.**
- **`life/CLAUDE.md`, `personal/CLAUDE.md`** — loose non-code directories. No action.
- **The ~100 worktree config directories** — no action, per epic decision 7.
- **Retire `docs/ARCHITECTURE-REVIEW-2026-07.md`'s open question** "Should an unconfigured
  `make check` fail, warn-and-pass, or be replaced?" — answered by this epic. Append the answer
  and a pointer to this spec rather than editing the review's body; it is a dated audit record.

### Part C — the closing audit
Write `scripts/audit-harness.sh` in the base: re-runs the epic's inventory and fails if any
non-worktree, non-archive path still contains `FLOOR.md`, `make/gate.mk`, or a `CLAUDE.md` that is
neither a one-line `@AGENTS.md` import nor an adapter file whose first non-comment line is that
import. This is what makes "standardized" a testable claim instead of an assertion, and it is what
catches the next repo that drifts.

## Task decomposition
1. smoke-screen: break the `CLAUDE.md`/`AGENTS.md` circularity; merge in the worktree policy — deps: none
2. smoke-screen: lift commands + the build-is-typecheck and no-formatter facts; delete `Makefile`/`make/` — deps: #1
3. smoke-screen: convert the three per-directory `CLAUDE.md` → `AGENTS.md` + import stubs — deps: #1
4. smoke-screen: fill `lint-edited-file.sh`; refresh `.claude/`; reconcile `.codex/` — deps: #2
5. Sweep: melting v1, life-os, opt/depot, archives — decide and **record each**, migrate none
   without asking — deps: none
6. Append the answer to the architecture review's open question — deps: none
7. Write `scripts/audit-harness.sh`; run it; fix or record every hit — deps: all of 01–07

## Acceptance criteria
- [ ] #1: the worktree policy appears exactly once in the repo, in the root `AGENTS.md`; neither
      instruction file tells the reader to see the other for it
- [ ] #2: `AGENTS.md` states that `build` is the typecheck and that there is no repo-wide formatter
- [ ] #2: `rg -n "make check|make/gate" .github/ AGENTS.md CLAUDE.md` returns nothing; CI green
- [ ] #3: each of the three areas has `AGENTS.md` + a one-line `CLAUDE.md`; reading a file in
      `services/api` loads that area's file and not the other two
- [ ] #4: editing a `.ts` file in `apps/smoke-web` surfaces eslint's error for **that file**, with
      the correct workspace config resolved — verified against a file in each of the three areas
- [ ] #5: every straggler has a recorded decision in the PR description; none migrated without asking
- [ ] #7: `bash scripts/audit-harness.sh` exits 0 across the machine
- [ ] #7: the audit script's own failure mode is tested — temporarily reintroduce a `FLOOR.md` in a
      scratch dir and confirm it exits non-zero (an audit that cannot fail proves nothing)

## Out of scope
- smoke-screen's application code, npm scripts, and `docs/technical/ui-design-standards.md`.
- Migrating any straggler without explicit approval (#5).
- Anything under `dev/archive/`.
- Rebasing or repairing the ~100 worktrees.

## Risk hotspots touched
None of the convergent set. One repo-specific hazard: smoke-screen's worktree/`.env` policy is
load-bearing — the file itself warns that a self-referential symlink crashes vite with `ELOOP` and
that all builds and tests fail without the symlinks. Moving that policy between files is the single
riskiest edit in this task. Move it first (#1), verify it reads correctly in a fresh session, and
only then touch anything else.

## Context pointers
- `smoke/code/smoke-screen/{CLAUDE.md,AGENTS.md}` — the circular pair; `diff` and reconcile
- `smoke/code/smoke-screen/.claude/rules/worktree-setup.md` — the third copy of the policy
- `smoke/code/smoke-screen/make/gate.mk` — holds the build-is-typecheck and no-formatter facts
- `smoke/code/smoke-screen/{apps/smoke-web,apps/smoke-admin,services/api}/CLAUDE.md` — the prior art
- `smoke/code/smoke-screen/scripts/link-worktree-env.sh` — the bootstrap step
- `docs/ARCHITECTURE-REVIEW-2026-07.md` §8 — the open question to close
- This epic's README — the audit table `audit-harness.sh` reproduces

## Verification
- checks: smoke-screen's declared commands from a clean `npm ci` + `link-worktree-env.sh`; CI green
- manual: fresh session in smoke-screen — confirm the worktree policy is present and unambiguous;
  read one file in each of the three areas and confirm the right area file loads each time; edit a
  file in each and confirm the lint hook resolves the right eslint config (`verify-before-done`)
- machine: `bash scripts/audit-harness.sh` green, and its failure path proven
