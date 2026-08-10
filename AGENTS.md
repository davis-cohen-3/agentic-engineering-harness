# agentic-coding-harness — repo profile

This is the repo's PROFILE: its stack, structure, commands, conventions, and tuned hotspots.
It is the **single** profile — Codex reads this file natively and `CLAUDE.md` imports it, so a
fact lives here once and both providers see it. Do not restate any of it in `CLAUDE.md`.

## What this is
A **portable two-provider coding harness** — skills, agents, hooks, path-scoped rules, a `make`
quality gate, and spec/plan scaffolding — that drops into any repo and travels into a sandbox
clone via `git clone`. There is **no app runtime**: the product *is* the harness. A target repo
inherits it via the `adopt-harness` skill, which fills the slots in `docs/OVERLAY-CONTRACT.md`.

## Stack
Bash hooks, a `make/gate.mk` quality gate (plain `make`), Python 3 for the registry and tests,
and markdown skills/agents/rules. No compiler, no server, no package manager.

## Structure map
The harness carries **two payloads**, never conflated. `specs/harness-standardization/CONTRACT.md`
§5 is the authority.

- `core/` — the **machine** payload, published to `~/.agents/` by `install.sh`: `skills/`,
  `rules/`, `claude/agents/` + `codex/agents/`, and `hooks/` (which holds *only*
  `inject-global-rules.sh` — every other hook is repo-owned, per decision K).
- `adopt/` — the **target-repo** payload: `AGENTS.template.md` + `CLAUDE.template.md`, `hooks/`
  (one copy, two bindings), `settings.json` and `codex/hooks.json`, the base `Makefile`,
  `make/gate.example-*.mk`, `specs/`, `docs/`.
- `packs/` — versioned but installed nowhere: project-layer, area-pack, retired and
  layer-undecided skills. See `packs/README.md`.
- `bin/` — `wt` (the worktree command) and `workspace-record`. `install/` — the registry migration.
- `test/` — the acceptance suites the gate runs: install · adopt · workspace · hooks · contract.
- `.claude/` — this repo's *own* project layer only: `commands/ship.md`, `skills/open-a-pr/`,
  path-scoped `rules/`, and `settings.json` binding the hooks out of `adopt/hooks/`.
- `Makefile` (root, one line: `include adopt/Makefile`) + `make/gate.mk` — this repo's gate.
- `docs/` — the harness author's space, which does **not** travel: design narrative
  (`OVERLAY-CONTRACT.md`, `PLAN-MODE.md`, `SOURCES.md`), curation catalogs (`recommended/`),
  and the observed-failure-mode log (`AGENT-ANTIPATTERNS.md`). Start at `docs/INDEX.md`.
- `specs/` — this repo's real specs. The traveling template scaffold is `adopt/specs/`.

## Commands
- **Quality gate (defines "done"):** `make check` — here it validates the *harness itself*:
  config is valid JSON, hooks are executable, and five acceptance suites pass. Never hand-roll
  the steps.
- **Bootstrap a fresh clone/worktree:** `make setup` (no-op here; load-bearing in target repos).
- **Cut a worktree:** `wt <project> --branch <b>` — branches from `origin/main`, creates
  `.workspace/`, runs `make setup`.

## Conventions (enforced here)
- **Single-source / no duplication** — every fact has ONE home; everything else *links* to it.
  This is the repo's central discipline, and this profile obeys it: it names owners, never
  restates them.
- **Extract, don't copy** — shared content moves to one place and is imported, never pasted
  (`CLAUDE.md` importing this file is the worked example).
- **Anti-bloat** — the default answer to "add a skill/rule/doc?" is **NO**. Always-on text must
  earn its token tax broadly. Justify additions against `docs/recommended/`, which owns the cap.
- **Vendored content stays ~verbatim** — upstream-sourced skills keep their original text;
  attribution and re-points are logged in `core/skills/VENDORED.md`. A harvested hook records
  its source blob SHA in its own header.
- **Scoped conventions live in `.claude/rules/`, not here** — a convention tied to a file-type
  or area belongs in a `paths:`-scoped rule file.
- **A change to an agent touches two files** — the Claude `.md` and the Codex `.toml`. Their
  bodies must stay byte-identical; `make check` asserts it.

## Tuned hotspots (this repo)
Touching any of these escalates care regardless of task size. Beyond the convergent base set —
migrations · auth · payments · outbound-send (email/LLM/webhooks) · prod deploy · spend — the
risk surface *here* is the harness machinery itself:
- `adopt/hooks/` — a broken guardrail's blast radius is every future run in every repo that
  inherits it. Every hook is a guard that must fail OPEN on a missing dependency and BLOCK on a
  real hit, under **both** providers' payload shapes.
- `install.sh` and `core/` — `core/` is published over `~/.agents/`; a defect here reaches every
  repo on the machine. The swap, the backup, and the refuse-on-drift check are load-bearing.
- `bin/wt` — it creates and names real worktrees and branches from a registry it parses. A test
  that invokes it must pin **both** `XDG_CONFIG_HOME` and cwd into a sandbox; without both it
  resolves the real registry and cuts real worktrees in real projects.
- `make/gate.mk` + `adopt/Makefile` — these *define* "done"; a wrong gate silently passes bad work.

## Working agreement
- Work on a **task branch**; never commit to the default branch (a hook enforces it). Ship via
  PR (`/ship` → `open-a-pr`). Commit and push only when asked.
- A change is done only when `make check` passes **and** you ran the change and watched the
  intended behaviour work. Compiling is not working. **Never claim done on unrun code** — the
  full definition is owned by the `verify-before-done` skill.
- Match the surrounding code's structure and idiom. Comment the non-obvious *why*, never the *what*.
- Secrets are never committed. Config references `${VAR}`, never a value.
- **No reviewer runs automatically.** `reviewer` and `reviewer-security` run only when asked for.
