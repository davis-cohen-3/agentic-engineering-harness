> ## ⚠ SUPERSEDED — DO NOT EXECUTE
>
> Replaced as the execution index by `plan/tasks.md`. It deletes the quality gate (retained), makes `~/agents` canonical (retired), declares worktrees out of scope (they are central), deletes the injection hook (kept), and retains active-spec binding (deleted by DEC-6).
>
> **Authority:** `DECISIONS-PENDING.md` → `CONTRACT.md` →
> `docs/HARNESS-DEPOT-OPERATIONAL-DESIGN-REVIEW.md` → `plan/tasks.md`.
> Retained as provenance and research. Harvest evidence from it; do not run its instructions.
>
> *Bannered 2026-08-08.*

# Epic: standardize the harness on the native CLAUDE.md / AGENTS.md hierarchy

**Why:** the harness invented three mechanisms that Claude Code and Codex now provide natively,
and each one costs tokens and drifts:

1. **`make check` as the definition of "done."** The base `Makefile` + `make/gate.mk` demand a
   *format* (`GATE_STEPS` as named make targets) rather than a *capability*. In practice every
   adopted repo's gate is a pass-through to scripts it already had. smoke-screen's `make/gate.mk`
   is the proof — its own comment says "Steps delegate to the repo's real npm scripts so the gate
   never drifts from CI," and the body is `lint: npm run lint` / `build: npm run build` /
   `test: npm run test`. `make check` → `make lint` → `npm run lint` is two layers of indirection
   over a command that already existed.
2. **`.claude/FLOOR.md` as an always-on floor.** ~90% of it duplicates content that already has a
   home (see the table below), and it re-states `make check` in seven places across the tree —
   violating the harness's own "single-source / no duplication" convention (`CLAUDE.md:47`).
3. **`~/.claude/hooks/inject-global-rules.sh`** — a bespoke SessionStart hook that concatenates
   `~/.claude/rules/*.md` and suppresses them inside projects. Claude Code already loads
   `~/.claude/CLAUDE.md` on every session and concatenates it with the project's file.

Both vendors converged on the same model: **one instruction file per directory, walked root → cwd,
concatenated, most-specific last.** Claude Code does it with `CLAUDE.md`; Codex does it with
`AGENTS.md` (`~/.codex/AGENTS.md` → `<git-root>/AGENTS.md` → intermediate dirs → cwd). The harness
should ride that hierarchy instead of building a parallel one.

This is a T3 because it spans the harness base, two hook rewrites, a new skill, the propagation
mechanism, the machine-level config, and three adopted repos — and the pieces must land in order.

## The target model

| Layer | File | Holds |
|-------|------|-------|
| Machine | `~/agents/AGENTS.md`, symlinked to `~/.claude/CLAUDE.md` + `~/.codex/AGENTS.md` | general prefs true in every repo |
| Project | `<repo>/AGENTS.md` (+ `CLAUDE.md` = one line, `@AGENTS.md`) | what it is · stack · structure · **its real commands** · hotspots |
| Area | `<repo>/<subdir>/AGENTS.md` | that area's commands only — loads on demand |

Checks become three tiers, none of them a gate:

| When | What | Cost |
|------|------|------|
| Every edit | `lint-edited-file.sh` lints **only** `tool_input.file_path` | ~ms |
| Pre-hand-back / PR | the repo's real test + typecheck commands, named in prose | seconds–minutes |
| On the user's word | `/e2e` (`disable-model-invocation: true`) | expensive, opt-in |

## Where FLOOR.md's content goes

| FLOOR content | New home |
|---------------|----------|
| task branch · ship via PR · minimal comments · match idiom | `~/agents/AGENTS.md` — **already verbatim** in `~/.claude/rules/00-preferences.md` |
| Definition of done | `verify-before-done/SKILL.md` (already states it) |
| Two modes · T0–T3 tiers · spec binding · one-run-one-task | `specs/README.md` + the plan/build skills |
| Risk hotspots | the project's own `AGENTS.md` (they were always per-project) |
| Skill markers | each `SKILL.md` already declares its own `STARTER_CHARACTER` |
| `make check` is the gate | deleted |

## Shared context (linked ONCE here; sub-specs point back, never restate)

**Primary sources — the design is grounded in these, not in preference:**
- [Claude Code · Best practices](https://code.claude.com/docs/en/best-practices) — "There's no
  required format for CLAUDE.md files"; the four-rung verification ladder (in-prompt → `/goal` →
  Stop hook → verification subagent), "Each step trades setup for attention"; the platform
  overrides a Stop hook after **8** consecutive blocks.
- [Claude Code · Memory](https://code.claude.com/docs/en/memory) — "Claude Code reads `CLAUDE.md`,
  not `AGENTS.md`… create a `CLAUDE.md` that imports it"; subdirectory files load **on demand**;
  only **project-root** `CLAUDE.md` is re-injected after `/compact`.
- [Claude Code · Hooks](https://code.claude.com/docs/en/hooks) — PostToolUse receives
  `tool_input.file_path`; exit 2 shows stderr to Claude; `hookSpecificOutput.additionalContext`
  injects a system reminder.
- [Codex · AGENTS.md](https://developers.openai.com/codex/guides/agents-md) — root → cwd
  concatenation, `AGENTS.override.md` replaces rather than appends, 32 KiB `project_doc_max_bytes` cap.
- [obra/superpowers · verification-before-completion](https://github.com/obra/superpowers/blob/main/skills/verification-before-completion/SKILL.md)
  — discipline with **zero** format: step 1 is "IDENTIFY: what command proves this claim?"

**In-repo:**
- `docs/ARCHITECTURE-REVIEW-2026-07.md` §C and §D — already flagged both the floor bloat and the
  no-op gate, and left "Should an unconfigured `make check` fail, warn-and-pass, or be replaced?"
  as an open question. This epic answers it.
- `docs/OVERLAY-CONTRACT.md` — slots 2 and 4 are the two being removed.
- `.claude/skills/adopt-harness/copy.sh` — the manifest that defines what travels.

## Audit — the machine, as of 2026-08-06

Scanned `~` to depth 6, excluding `node_modules`, `Library`, `.venv`, build output.
**~110 `.claude`/`.codex`/`.agents` directories exist, but only 8 are canonical checkouts.**
The rest are worktrees that regenerate from their source repo.

| Path | Kind | `.claude` | `.codex` | `.agents` | `CLAUDE.md` | `AGENTS.md` | `FLOOR.md` | `Makefile` | `gate.mk` |
|------|------|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| `dev/agentic-engineering` | repo (base) | ✓ | — | — | ✓ | — | ✓ | ✓ | ✓ |
| `dev/depot` | repo | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `smoke/code/smoke-screen` | repo | ✓ | ✓ | — | ✓ | ✓ | — | ✓ | ✓ |
| `melting/code/melting-v2` | repo | ✓ | ✓ | — | ✓ | ✓ | — | ✓ | ✓ |
| `melting/code/v1` | repo | ✓ | — | — | ✓ | — | — | — | — |
| `dev/life-os` | no git | ✓ | — | — | — | — | — | — | — |
| `opt/depot` | worktree of depot | ✓ | — | — | ✓ | — | ✓ | ✓ | ✓ |
| `~` (machine) | — | ✓→`~/agents/claude` | ✓ | ✓ | — | ✓ (**empty**) | — | — | — |

**Confirmed drift, all found during the audit:**
- **`dev/depot`'s `CLAUDE.md` and `AGENTS.md` have forked into different repositories.**
  `CLAUDE.md` describes a "local-first web cockpit… FastAPI daemon… React PWA… the old Textual TUI
  is retired and removed." `AGENTS.md` describes "a single-pane Textual TUI" that is "in
  transition," with `src/depot/app.py` marked FROZEN. Every Codex session in depot has been reading
  a description an architecture generation out of date. This is the epic's most damaging single finding.
- `dev/depot/AGENTS.md:7` imports `@.Codex/FLOOR.md` — capital `C`, on a case-sensitive path.
  It silently resolves to nothing; depot's Codex sessions have been running with no floor either.
- `dev/depot/.claude/hooks/spec-session-orient.sh` differs from `.codex/hooks/spec-session-orient.sh`.
- `dev/depot/.agents/skills/` is missing `VENDORED.md` relative to `.claude/skills/`.
- smoke-screen and melting-v2 have `Makefile` + `gate.mk` but **no** `FLOOR.md`, while their own
  worktrees under `workspaces/smoke-screen/*` **do** carry `FLOOR.md` — the base and its adopters
  are on different harness generations.
- `~/.codex/AGENTS.md` exists and is **empty** — the Codex machine layer was never populated.
- `~/.claude` is a symlink to `~/agents/claude`, but `~/.codex` and `~/.agents` are real
  directories; `~/agents/codex/` and `~/agents/hermes/` exist and are empty. The consolidation
  under `~/agents/` was started and abandoned.
- smoke-screen's `CLAUDE.md` and `AGENTS.md` reference each other circularly ("See `AGENTS.md`…"
  / "See `CLAUDE.md` for full project structure") with overlapping content in both.
- smoke-screen already ships per-directory `CLAUDE.md` in `apps/smoke-web`, `apps/smoke-admin`,
  and `services/api` — **working prior art for the target model**, adopted ad hoc rather than by
  the harness. Codex cannot see any of them.

**Two places the machine already got it right** — the target model is not speculative:
- `melting/code/melting-v2/CLAUDE.md` is already a clean adapter: `# Claude Code adapter`, then
  `@AGENTS.md`, then Claude-only routing. Exactly the shape this epic standardizes on.
- `melting/code/melting-v2/make/gate.mk` carries a `verify: npm run test:pg` target commented
  *"DB-backed test tier (NOT in the gate) — what verify-before-done runs for DB-backed tasks."*
  The expensive tier was already opt-in there; this epic generalizes that instinct into `/e2e`.

## Tasks (ordered; each is ONE build run)

| #  | Sub-spec | Deps | Hotspots | Status |
|----|----------|------|----------|--------|
| 01 | [strip the gate and the floor from the base](./01-strip-gate-and-floor.md) | — | — | ready |
| 02 | [per-edit lint hook + unattended-only Stop hook](./02-hooks.md) | 01 | — | ready |
| 03 | [`/e2e` skill + trim `verify-before-done`](./03-e2e-skill.md) | 01 | — | ready |
| 04 | [rewrite `adopt-harness` + the copy manifest](./04-adopt-harness.md) | 01, 02, 03 | — | ready |
| 05 | [machine layer: `~/agents`, `~/.claude`, `~/.codex`](./05-machine-layer.md) | 01 | — | ready |
| 06 | [migrate melting-v2 (proving ground)](./06-migrate-melting.md) | 04 | — | ready |
| 07 | [migrate depot](./07-migrate-depot.md) | 04, 06 | migrations, prod-deploy | ready |
| 08 | [migrate smoke-screen + sweep](./08-migrate-smoke-screen-and-sweep.md) | 04, 06 | — | ready |

## Sequencing & integration

Eight build runs. **01 must land first** — it defines the shape everything else conforms to.
02, 03 and 05 are independent of each other and may run in any order after 01; 02 and 03 are
prerequisites for 04 only because `copy.sh`'s manifest must enumerate the files they create.
04 is the propagation mechanism, so **06, 07 and 08 cannot start until it lands** — otherwise
each migration hand-rolls its own interpretation of the new shape and they diverge again, which
is the exact failure this epic exists to fix.

The three migrations run **hardest-last**, not worst-first. melting-v2 (06) goes first because it
already implements most of the target — its `CLAUDE.md` is a proper `@AGENTS.md` adapter and its
`gate.mk` already separates an opt-in expensive tier — so it proves the recipe at the lowest risk.
depot (07) is the worst-drifted and follows once the recipe holds. smoke-screen (08) is last and
carries the closing machine-wide audit. 07 and 08 depend on 06 for the recipe, not for code.

Each run is a separate branch and PR in its own repo. Note that 06–08 are PRs against **other
repositories** (`dev/depot`, `smoke/code/smoke-screen`, `melting/code/melting-v2`), not this one.

## Epic-level decisions (settled once; sub-specs inherit, don't re-litigate)

1. **`AGENTS.md` is canonical; `CLAUDE.md` is a one-line `@AGENTS.md` import.** Codex reads
   `AGENTS.md` natively and Claude Code does not, so the neutral file is the source and the
   Claude-specific file is the adapter. Not a symlink at the repo level — the import form leaves
   room to append Claude-only content below it, and symlinks break on Windows without Developer Mode.
2. **The machine layer concatenates; it does not suppress.** `inject-global-rules.sh` exists
   because the global rules were repo-specific enough to be wrong inside a project. The fix is to
   make them general enough to always be true, not to conditionally hide them. Retiring the hook
   also removes a bespoke mechanism from the critical path of every session.
3. **`.claude/rules/` dissolves into per-directory `AGENTS.md`.** A rule scoped by `paths:` and a
   `CLAUDE.md` in that directory do the same job, and the directory file is visible to Codex,
   visible to a human browsing the tree, and needs no frontmatter. Path-scoped rules also share
   the subdirectory files' compaction weakness, so there is nothing left to prefer them for.
4. **Anything that must survive `/compact` lives in the project-root file.** Only project-root
   `CLAUDE.md` is re-injected after compaction; subdirectory files reload only when a file in that
   directory is next read. Area files therefore carry commands and local conventions — never a
   safety-critical rule.
5. **No replacement gate.** No `checks.json`, no `scripts/check.sh` contract, no successor to
   `GATE_STEPS`. The commands are named in prose and the agent runs the right one. This is the
   decision most likely to be second-guessed mid-build: don't. A machine-readable check list is
   the same mistake in a different file format.
6. **The Stop hook survives, scoped to unattended runs only** (`HARNESS_UNATTENDED=1`). It is the
   one part of the old gate that earns its cost, because Warren decides a run succeeded from the
   agent's own envelope. It must never fire in an interactive session.
7. **Worktrees are out of scope and are not migrated.** They regenerate from their source repo.
   The ~100 worktree config directories in the audit are noise; migrating a repo fixes its future
   worktrees automatically.
8. **`docs/` does not travel** (unchanged from today) and neither does this `specs/` epic.

## Binding a build run to a sub-spec

Each run sets its pointer to the specific sub-spec, not this index. Task 01 deletes
`make work`, so from 01 onward the bind is:
`echo specs/harness-standardization/01-strip-gate-and-floor.md > .claude/active-spec`
