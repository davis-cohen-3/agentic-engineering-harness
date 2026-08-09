# agentic-coding-harness — repo profile

> This repo's always-on context: what it is, how it is laid out, how to check it, and the rules
> that must fire on every task here. There is no inherited floor file — `.claude/FLOOR.md` was
> removed and its content redistributed to the owners named below.

## Always-on rules
- **Done** means the gate is green AND you ran the change AND you reviewed your diff against the
  plan. The full definition, and why a green gate alone is not enough, is owned by the
  `verify-before-done` skill. **Never claim done on unrun code.**
- **Work on a task branch**, never the default branch (a hook enforces this). Ship via PR
  (`/ship` → `open-a-pr`). Commit/push only when asked.
- **Match the surrounding code's idiom. Prefer minimal-to-no comments** — the non-obvious *why*,
  never the *what*.
- **Design in plan mode, execute in build mode.** A build run does not redesign. Task tiers
  `T0`–`T3` size the response; `specs/README.md` owns the definitions. **One run builds one task.**
- **Spec not `ready`, or an unresolved design question? HARD-STOP and flag it** — do not invent
  the design; hand back "blocked: design gap at <X>".
- `make check`, risk-review on a hotspot, and `verify-before-done` **never scale down.**
- Secrets are never committed; `.mcp.json` holds `${VAR}` references, never values.
- While a skill is active, open each reply with its `STARTER_CHARACTER`. No skill → no marker.
- **No reviewer runs automatically** — `reviewer` and `reviewer-security` run only when asked.

## What this is
A **portable Claude Code harness base** — skills, agents, hooks, path-scoped rules, a `make`
quality gate, and spec/plan scaffolding — that drops into any repo and travels into a
Warren/burrow sandbox via `git clone`. There is **no app runtime**: the product *is* the harness.
A target repo inherits it via the `adopt-harness` skill, which fills the slots defined in
`docs/OVERLAY-CONTRACT.md`.

## Stack
Bash hooks (`core/hooks/`), a `make/gate.mk` quality gate (plain `make`), and markdown
skills/agents/rules. No compiler, no server, no package manager.

## Structure map

⚠ **Mid-restructure (Wave 0 of `specs/harness-standardization/`).** The harness now carries two
payloads instead of one traveling `.claude/` tree. `CONTRACT.md` §5 is the authority.

- `core/` — the **machine** payload, published to `~/.agents/` by `install.sh`: `skills/`,
  `hooks/`, `rules/`, `claude/agents/` + `codex/agents/`. See `core/README.md`.
- `adopt/` — the **target-repo** payload: `CLAUDE.template.md`, the base `Makefile`,
  `make/gate.example-*.mk`, `specs/` (README + templates).
- `packs/` — versioned but installed nowhere: project-layer, area-pack, retired and
  layer-undecided skills. See `packs/README.md`.
- `.claude/` — this repo's *own* project layer only: `commands/ship.md`, `skills/open-a-pr/`,
  path-scoped `rules/` (`migrations.md`, `specs.md`; authoring guide in
  `docs/CLAUDE-CODE-RULES.md`), and `settings.json` binding the hooks out of `core/hooks/`.
- `Makefile` (root, one line: `include adopt/Makefile`) + `make/gate.mk` — this repo's gate.
- `docs/` — the harness author's space (does NOT travel): design narrative
  (`OVERLAY-CONTRACT.md`, `PLAN-MODE.md`, `SOURCES.md`) + curation catalogs (`recommended/`) +
  the observed-failure-mode log (`AGENT-ANTIPATTERNS.md`). (Orchestrator/Warren requirements
  live outside this repo — the harness scope ends at the spec hand-off.)
- `agent_docs/` — deep reference (architecture, glossary, ADRs); start at its README.
- `specs/` — this repo's real specs. The template scaffold moved to `adopt/specs/`.

## Commands
- **Quality gate (defines "done"):** `make check` — here it validates the *harness itself*
  (config is valid JSON, hooks are executable), composed from `make/gate.mk`. Never hand-roll
  the steps.
- **Bootstrap a fresh clone/worktree:** `make setup` (no-op here; load-bearing in target repos).

## Conventions (enforced here)
- **Single-source / no duplication** — every fact has ONE home; everything else *links* to it
  (this PROFILE references owners, never restates them). This is the repo's central discipline.
- **Extract, don't copy** — shared content moves to one place and is imported/linked, never
  pasted (`CLAUDE.md` importing `AGENTS.md` rather than restating the profile is the worked
  example).
- **Anti-bloat** — the default answer to "add a skill/rule/doc?" is **NO**. Always-on text must
  earn its token tax broadly; keep within the skill budget. Justify additions against
  `docs/recommended/` (which owns the concrete cap + current count).
- **Vendored skills stay ~verbatim** — upstream-sourced skills keep their original text;
  attribution and any re-points are logged in `core/skills/VENDORED.md`.
- **Scoped conventions live in `.claude/rules/`, not here** — this section holds only the
  always-on, repo-wide few; a convention tied to a file-type or area belongs in a rule file
  (usually `paths:`-scoped), per the `.claude/rules/` entry above.

## Risk hotspots — slow down, engage `reviewer-security`, never skip review
The convergent base set: **migrations · auth · payments · outbound-send (email/LLM/webhooks) ·
prod deploy · spend.** Beyond it, the risk surface *here* is the harness machinery itself:
- **`core/hooks/`** — a broken guardrail's blast radius is every future run in every repo
  that inherits it. Treat any hook change as a hotspot; engage `reviewer-security`.
- **`make/gate.mk` + `adopt/Makefile`** — these *define* "done"; a wrong gate silently passes
  bad work.
- **`core/` and `install.sh`** — `core/` is published over `~/.agents/`; a defect here reaches
  every repo on the machine.
