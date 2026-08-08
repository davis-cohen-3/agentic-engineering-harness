> ## ⚠ SUPERSEDED — DO NOT EXECUTE
>
> Carries the bind script and `agent_docs/`, excludes required target surfaces, and lacks Codex project skill discovery. Replaced by tasks T0.4 and T0.5.
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

# 04 · Rewrite `adopt-harness` + the copy manifest

> Part of the [harness standardization](./README.md) epic — read its **Shared context** and
> **Epic-level decisions** first.

## Goal
Make the propagation mechanism produce the new shape. `copy.sh`'s manifest *is* the definition of
the portable harness, so until it changes, nothing else can be migrated consistently. After this
run, adopting the harness into a repo yields `AGENTS.md` + a one-line `CLAUDE.md` + hooks, and
never a `Makefile`.

**This is the gate for tasks 06–08.** They must not start before this lands, or each migration
hand-rolls its own reading of the new shape and the tree diverges again.

## Approach (resolved at the epic level — execute, don't re-decide)

### `copy.sh` — the manifest
Remove: `Makefile`, `make/gate.example-python.mk`, `make/gate.example-ts.mk`, `.claude/rules`.
Rename: `CLAUDE.template.md` → `AGENTS.template.md`.
Add: `scripts/` (carries `bind-spec.sh`; `install-global.sh` must **not** travel — it is
harness-only and already self-guards, but shipping it into an adopted repo invites a stale
`.claude/` being pushed over global config).

So the post-change manifest is:
```
AGENTS.template.md      → renamed to AGENTS.md in the target
.claude/settings.json
.claude/skills          (adopt-harness pruned, as today)
.claude/agents
.claude/hooks
.claude/commands
.mcp.json
scripts/bind-spec.sh
specs
agent_docs
.gitignore
```

Post-copy steps `copy.sh` must now perform:
- `AGENTS.template.md` → `AGENTS.md`, never clobbering an existing one (same guard as today's
  `CLAUDE.md` handling).
- **Create `CLAUDE.md` containing `@AGENTS.md`.** If a `CLAUDE.md` already exists, leave it and
  warn — a repo like smoke-screen has a real one, and silently truncating it to an import line
  would destroy content. The warning must name the file and say what to do.
- Drop the `GATE_FLAVOR` argument entirely. `copy.sh` takes one argument now: the target path.
  There is nothing left to choose between `python` and `ts`, because the checks are prose the
  adopter writes, not an example file we install.
- Keep: self-location from `$BASH_SOURCE`, refusal to adopt a repo into itself, the
  `adopt-harness` self-prune, and the "adopt once per repo" warning.

### `SKILL.md`
- §1: the invocation loses its second argument → `<harness-path>/.claude/skills/adopt-harness/copy.sh .`
- §2 (scout the repo): the scout brief changes from "the real **gate** commands" to "the repo's
  real lint / typecheck / test commands **and which directories have their own**" — the second
  half is new and is what makes per-area `AGENTS.md` possible. Also have scout report which
  linters can run on a **single file**, since that's what task 02's hook needs.
- §3 (draft the fills): the three fills become four —
  1. `AGENTS.md` — `<FILL>`s: what / stack / structure / commands / conventions / hotspots
  2. per-area `AGENTS.md` for any subdirectory with its own toolchain (a monorepo package, a
     `web/` frontend inside a Python repo) — commands and local conventions only, never a
     safety-critical rule, because subdirectory files don't survive `/compact`
  3. `.claude/hooks/lint-edited-file.sh` — fill the `case` arms with this repo's single-file
     linters
  4. `agent_docs/architecture.md` + `glossary.md` (unchanged)
- §4 (verify): `make setup && make check` → run the repo's newly declared commands and confirm
  green; confirm `CLAUDE.md` is the one-line import and `/context` shows `AGENTS.md`'s content
  loaded; confirm no `FLOOR.md`, no `Makefile`, no `docs/`, no `recommended/`, no `adopt-harness/`
  in the copied tree.

### `docs/OVERLAY-CONTRACT.md`
Task 01 rewrote slots 1, 2 and 4. This run adds the one genuinely new slot the model introduces:
**single-file lint commands** (what `lint-edited-file.sh` dispatches on). Fold it into slot 2
rather than adding a ninth row — it is the same information at a different granularity, and a
contract that grows rows every time we learn something is how we got here.

## Task decomposition
1. Rewrite the `copy.sh` manifest + post-copy steps; drop `GATE_FLAVOR` — deps: none
2. Rewrite `SKILL.md` §§1–4 — deps: #1
3. Fold the single-file-lint requirement into OVERLAY-CONTRACT slot 2 — deps: #2
4. End-to-end rehearsal: adopt into a scratch repo, confirm the output — deps: #1, #2

## Acceptance criteria
- [ ] #1: `copy.sh` with two arguments errors on the extra argument rather than silently ignoring it
- [ ] #1: `rg -n "gate|Makefile|GATE_FLAVOR" .claude/skills/adopt-harness/copy.sh` returns nothing
- [ ] #4: in a fresh `git init` scratch repo, `copy.sh <scratch>` produces: `AGENTS.md` (from the
      template, `<FILL>`s intact), `CLAUDE.md` containing exactly `@AGENTS.md`, `.claude/` with
      skills/agents/hooks/commands and **no** `rules/`, `scripts/bind-spec.sh`, `specs/`,
      `agent_docs/`, `.mcp.json`, `.gitignore` — and **no** `Makefile`, `make/`, `FLOOR.md`,
      `docs/`, `adopt-harness/`, `install-global.sh`
- [ ] #4: re-running `copy.sh` on that same scratch repo leaves `AGENTS.md` untouched and warns
- [ ] #4: in a scratch repo that already has a real multi-line `CLAUDE.md`, `copy.sh` leaves it
      intact and warns — it does **not** overwrite it with the import line
- [ ] #4: a session started in the scratch repo loads `AGENTS.md` via `CLAUDE.md` (`/context`)

## Out of scope
- Adopting into any real repo — that is tasks 06–08.
- `install-global.sh` itself (task 01 ported it; this run only ensures it doesn't travel).
- A migration script for already-adopted repos. Each of 06–08 has repo-specific content to
  reconcile — depot's triple mirror, smoke-screen's real `CLAUDE.md` and existing per-directory
  files. A generic migrator would either be trivial (and not help) or wrong. Deliberately manual.

## Risk hotspots touched
None of the convergent set, but this is the highest-leverage diff in the epic: `copy.sh` is the
single source of truth for what travels, and an error here propagates into every repo adopted
afterward. Engage `reviewer` on the manifest specifically. Confirm the two never-clobber guards
(`AGENTS.md`, `CLAUDE.md`) actually cover the case where the target has one file but not the other.

## Context pointers
- `.claude/skills/adopt-harness/copy.sh` — the manifest is the whole point of the file; its header
  comment says so and must stay true after the rewrite
- `.claude/skills/adopt-harness/SKILL.md` — the four sections to rewrite
- `AGENTS.template.md` — produced by task 01; this run installs it
- `docs/OVERLAY-CONTRACT.md` — slot 2, as rewritten by task 01

## Verification
- checks: the base's declared checks from task 01
- manual: the full rehearsal in acceptance #4 — `mktemp -d`, `git init`, run `copy.sh`, inspect the
  tree, start a real session in it and check `/context`, then re-run `copy.sh` and confirm the
  guards hold. Delete the scratch dir afterward. Nothing about this task can be verified by
  reading the script (`verify-before-done`).
