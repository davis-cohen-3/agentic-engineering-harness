> ## ⚠ SUPERSEDED — DO NOT EXECUTE
>
> Deletes the Makefile and replaces spec binding with another active-spec script. The gate is **retained**; binding is **deleted entirely**. FLOOR removal survives as task T0.13 — harvest only the content-disposition research.
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

# 01 · Strip the gate and the floor from the harness base

> Part of the [harness standardization](./README.md) epic — read its **Shared context** and
> **Epic-level decisions** first; this sub-spec assumes them and does not repeat them.

## Goal
Remove `make` and `FLOOR.md` from `dev/agentic-engineering` and re-shape the base around
`AGENTS.md` + a one-line `CLAUDE.md`. After this run, nothing in the base tells an agent to run
`make check`, and the base itself is an example of the model it ships.

This run touches **only** `dev/agentic-engineering`. It does not touch hooks (02), the e2e skill
(03), `adopt-harness` (04), or any adopted repo.

## Approach (resolved at the epic level — execute, don't re-decide)

**Delete outright:**
- `.claude/FLOOR.md`
- `Makefile`
- `make/gate.mk`, `make/gate.example-python.mk`, `make/gate.example-ts.mk` (the whole `make/` dir)
- `.claude/rules/migrations.md` — it is a worked example for a directory the base doesn't have.
  The pattern it demonstrates is restated in one line in `AGENTS.template.md` ("area conventions
  go in that area's `AGENTS.md`"), which is where an adopter will actually look.

**Rescue from the Makefile before deleting it** — both targets are unrelated to checks and still
needed. Port them verbatim, keeping the existing input validation (the `SPEC` path guard against
`..` and non-`specs/` paths, and `install-global`'s harness-only guard):
- `make work SPEC=…` → `scripts/bind-spec.sh <spec-path>` (still writes `.claude/active-spec`;
  `.claude/hooks/spec-session-orient.sh` reads it and is otherwise unchanged)
- `make install-global` → `scripts/install-global.sh` (still `rsync`s `skills`/`agents`/`commands`
  only, still honors `CLAUDE_CONFIG_DIR` and `DELETE=--delete`)

**Restructure the base's own instruction files:**
- `CLAUDE.md` → `AGENTS.md`, with the `@.claude/FLOOR.md` import removed and the two-part
  "PROFILE + FLOOR" preamble deleted. Add a `## Commands` section naming this repo's real checks
  as raw commands (see Verification below).
- New `CLAUDE.md` containing exactly one line: `@AGENTS.md`
- `CLAUDE.template.md` → `AGENTS.template.md`. Drop the PROFILE/FLOOR framing and the
  `@.claude/FLOOR.md` import. Its `## Commands` slot changes from "`make check` — never hand-roll
  the steps" to a `<FILL>` for the repo's real lint/typecheck/test commands, plus a note that
  area-specific commands belong in that area's `AGENTS.md`.
- `.claude/rules/specs.md` → `specs/AGENTS.md`. Same content; it was already scoped to `specs/`,
  so the directory file does the job with no frontmatter and Codex can see it.
- `.claude/rules/` is then empty and is removed.

**Strip `make check` from every remaining reference.** All 55 `gate`-family mentions were
inventoried; these are the ones that instruct behavior:
- `.claude/agents/reviewer.md:19` — "Gate first. Run `make check`" → "Run this repo's checks as
  named in its `AGENTS.md`. If they're red, that's finding #1 — stop and report."
- `.claude/skills/verify-before-done/SKILL.md:57` — step 1 → same substitution (the rest of that
  skill is task 03's business; this run changes only the `make check` line)
- `.claude/skills/open-a-pr/SKILL.md:18` — "Run the quality gate: `make check`" → "Run this repo's
  checks. Do not open a PR until they pass."
- `.claude/commands/ship.md` — the parenthetical "quality gate → description → open"
- `specs/templates/t1/spec.md:20`, `t2/spec.md:70`, `t2/spec.context.md:27`,
  `t3/01-queue-table.md:31,46`, `t3/02-worker.md:30,44`, `t3/03-retry-dlq.md:32,45` — each
  `make check` in an acceptance criterion or `gate:` line becomes the illustrative repo's real
  command (`uv run pytest -q`, matching those templates' Python example)
- `README.md` — **two** things, not one: the adoption walkthrough (line ~32, `make setup && make
  check` → the repo's own commands, and the parenthetical listing FLOOR as something that travels)
  **and** the touchpoint table — row 1 "Always-on floor | `CLAUDE.md` (PROFILE) + `.claude/FLOOR.md`"
  (line ~48) collapses to the `AGENTS.md` hierarchy, and row 3 "Quality gate | `Makefile` + `make/gate.mk`"
  (line ~50) becomes the repo's declared commands. Lines ~61 and ~77 also name the gate.
- `agent_docs/architecture.md:1`
- `docs/OVERLAY-CONTRACT.md` — **slot 2** ("a list of named checks", `GATE_STEPS`) is rewritten to
  "the repo's real commands, named in its `AGENTS.md`"; **slot 4** (verify harness / Playwright /
  Browserbase) is removed from the contract entirely — task 03 gives it a home in the `/e2e` skill.
  Slot 1 (setup/bootstrap) stays but loses `SETUP_STEPS` and becomes a prose bootstrap line.
- `docs/recommended/hooks.md:45` — the "`[ADD]` Run the gate on Stop" recommendation is task 02's
  to rewrite, but its `make check` reference is corrected here so the base is internally
  consistent at the end of this run.

**Leave alone:** `.claude/skills/VENDORED.md` (its `make check` mention is a historical note about
what we changed in a vendored skill — rewriting it would falsify the provenance record).

## Task decomposition
1. Port `work` + `install-global` to `scripts/`, and port `gate.mk`'s hook-executable-bit loop to
   `scripts/validate-hooks.sh`; verify all three run, then delete `Makefile` + `make/` — deps: none
2. Delete `.claude/FLOOR.md` and `.claude/rules/`; move `specs.md` → `specs/AGENTS.md` — deps: none
3. `CLAUDE.md` → `AGENTS.md` + one-line `CLAUDE.md`; `CLAUDE.template.md` → `AGENTS.template.md` — deps: #2
4. Strip `make check` from agents, skills, command, spec templates, README, architecture.md — deps: #1
5. Rewrite `docs/OVERLAY-CONTRACT.md` slots 1, 2, 4 — deps: #3

## Acceptance criteria
- [ ] #1: `bash scripts/bind-spec.sh specs/harness-standardization/01-strip-gate-and-floor.md`
      writes that path to `.claude/active-spec`; passing `../etc/passwd` or a non-`specs/` path
      exits non-zero without writing. `bash scripts/install-global.sh` run from a non-harness
      directory exits non-zero. `bash scripts/validate-hooks.sh` exits 0 with all hooks executable
      and non-zero after `chmod -x` on one of them (then restore it).
- [ ] #2: `rg -n "FLOOR" --glob '!docs/**' --glob '!specs/harness-standardization/**'` returns nothing
- [ ] #3: `CLAUDE.md` is exactly one line, `@AGENTS.md`; `/context` in a fresh session in this repo
      lists `CLAUDE.md` under Memory files and the loaded content is `AGENTS.md`'s
- [ ] #4: `rg -n "make check|GATE_STEPS|SETUP_STEPS|gate\.mk" --glob '!research/ARCHITECTURE-REVIEW-2026-07.md' --glob '!.claude/skills/VENDORED.md' --glob '!specs/harness-standardization/**'`
      returns nothing
- [ ] #5: OVERLAY-CONTRACT's slot table has 7 rows (slot 4 gone), and slot 2 names no file format
- [ ] the base's own checks, as newly declared in `AGENTS.md`, pass

## Out of scope
- The per-edit lint hook and the Stop hook rework (task 02) — `enforce-gate-on-stop.sh` still
  greps for `^check:` in a `Makefile` after this run and will therefore no-op and exit 0. That is
  a deliberate, safe intermediate state: it fails open, never blocks, and task 02 replaces it.
- The `/e2e` skill and the rest of `verify-before-done` (task 03).
- `adopt-harness` + `copy.sh` (task 04) — the manifest still lists `Makefile` and
  `make/gate.example-*.mk` after this run and would warn "missing in base, skipped". Task 04 is
  where the manifest is corrected. **Do not adopt this harness into any repo between 01 and 04.**
- Any repo other than `dev/agentic-engineering`.

## Risk hotspots touched
None of the convergent set. The tuned hotspot from the old profile still applies: `.claude/hooks/`
is not edited here, but `scripts/bind-spec.sh` becomes load-bearing for
`spec-session-orient.sh` — if the pointer format changes, every resumed session loses its spec.
Keep the file format identical: one line, the path, trailing newline.

## Context pointers
- `Makefile` — the `work` and `install-global` recipes to port, including their guards
- `.claude/FLOOR.md` — read before deleting; confirm each section has the home the epic README claims
- `docs/OVERLAY-CONTRACT.md` — the slot table
- `.claude/hooks/spec-session-orient.sh` — the consumer of `.claude/active-spec`; do not change it

## Verification
- checks: this repo validates itself — `python3 -c "import json,sys; [json.load(open(f)) for f in ('.claude/settings.json','.mcp.json')]"`
  and `bash scripts/validate-hooks.sh` (port the executable-bit loop out of the deleted `gate.mk`
  into this script; it is the base repo owning its own script, which is the model, not a mandated contract)
- manual: start a fresh session in the repo, run `/context`, confirm `CLAUDE.md` loads and
  `FLOOR.md` does not appear anywhere in the loaded set; run `bash scripts/bind-spec.sh` on a real
  spec and confirm a new session surfaces it (`verify-before-done`)
