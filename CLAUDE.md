# agentic-coding-harness — repo profile

> Two parts: the **PROFILE** below (this repo's stack, structure, commands, conventions, tuned
> hotspots) and the **FLOOR** — the repo-agnostic must-always-fire rules, imported just below
> from `.claude/FLOOR.md`, inherited byte-identical and never edited per repo. Onboarding a new
> repo regenerates this PROFILE and ships the FLOOR untouched.

@.claude/FLOOR.md

## What this is
A **portable Claude Code harness base** — skills, agents, hooks, path-scoped rules, a `make`
quality gate, and spec/plan scaffolding — that drops into any repo and travels into a
Warren/burrow sandbox via `git clone`. There is **no app runtime**: the product *is* the harness.
A target repo inherits it via the `adopt-harness` skill, which fills the slots defined in
`docs/OVERLAY-CONTRACT.md`.

## Stack
Bash hooks (`.claude/hooks/`), a `make/gate.mk` quality gate (plain `make`), and markdown
skills/agents/rules. No compiler, no server, no package manager.

## Structure map
- `.claude/FLOOR.md` — the inherited floor (imported above).
- `.claude/skills/` — the harness's own model- & `/`-invoked process skills (only these count
  against the skill budget; other skills in the picker are user/global). Upstream provenance in
  `VENDORED.md`; recommendation rationale in `docs/recommended/skills.md`.
- `.claude/agents/` — sub-agent definitions (`scout`/`researcher`, `reviewer`/`reviewer-security`).
- `.claude/hooks/` — deterministic guardrails (branch guard, secret-protect, gate-on-stop, …).
- `.claude/rules/` — conventions as standalone files; `paths:` frontmatter scopes a rule to
  matching files, otherwise it loads always-on like the floor (worked examples `migrations.md`,
  `specs.md`; authoring guide in `docs/CLAUDE-CODE-RULES.md`).
- `Makefile` (repo root, base, don't edit) + `make/` — `gate.mk` (this repo's gate) + `gate.example-*.mk`.
- `docs/` — the harness author's space (does NOT travel): design narrative
  (`OVERLAY-CONTRACT.md`, `PLAN-MODE.md`, `SOURCES.md`) + curation catalogs (`recommended/`) +
  the observed-failure-mode log (`AGENT-ANTIPATTERNS.md`). (Orchestrator/Warren requirements
  live outside this repo — the harness scope ends at the spec hand-off.)
- `agent_docs/` — deep reference (architecture, glossary, ADRs); start at its README.
- `specs/` — plan→build handoff specs (`templates/` + the lifecycle in its README).

## Commands
- **Quality gate (defines "done"):** `make check` — here it validates the *harness itself*
  (config is valid JSON, hooks are executable), composed from `make/gate.mk`. Never hand-roll
  the steps.
- **Bootstrap a fresh clone/worktree:** `make setup` (no-op here; load-bearing in target repos).

## Conventions (enforced here)
- **Single-source / no duplication** — every fact has ONE home; everything else *links* to it
  (this PROFILE references owners, never restates them). This is the repo's central discipline.
- **Extract, don't copy** — shared content moves to one place and is imported/linked, never
  pasted (the FLOOR `@import` is the worked example).
- **Anti-bloat** — the default answer to "add a skill/rule/doc?" is **NO**. Always-on text must
  earn its token tax broadly; keep within the skill budget. Justify additions against
  `docs/recommended/` (which owns the concrete cap + current count).
- **Vendored skills stay ~verbatim** — upstream-sourced skills keep their original text;
  attribution and any re-points are logged in `.claude/skills/VENDORED.md`.
- **Scoped conventions live in `.claude/rules/`, not here** — this section holds only the
  always-on, repo-wide few; a convention tied to a file-type or area belongs in a rule file
  (usually `paths:`-scoped), per the `.claude/rules/` entry above.

## Tuned hotspots (this repo)
Beyond the base set in the FLOOR, the risk surface *here* is the harness machinery itself:
- **`.claude/hooks/`** — a broken guardrail's blast radius is every future run in every repo
  that inherits it. Treat any hook change as a hotspot; engage `reviewer-security`.
- **`make/gate.mk` + the root `Makefile`** — these *define* "done"; a wrong gate silently passes
  bad work.
