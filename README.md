# agentic-coding-harness

A **portable two-provider (Claude Code + Codex) harness base**: repo-agnostic skills, agents,
hooks, and a definition of done that drops into any repository and travels into an autonomous sandbox (Warren/burrow)
**free via the git clone**.

The governing idea: the QUALITY of an agent's planning/building/reviewing lives in the
**harness**, not the orchestrator. This repo is that harness, made concrete.

## Two layers
- **The portable harness** — everything that travels into a target repo. The exact set is pinned
  by the manifest in `core/skills/adopt-harness/copy.sh`. The machine payload is `core/`; the
  target-repo payload is `adopt/`.
- **The author's notebook** (`docs/`) — design narrative + curation catalogs (`docs/recommended/`).
  This is where the harness is *justified and curated*; it does **not** travel.

## How to use it — port the harness into your repo
The **`adopt-harness`** skill is the single source for *how*; this is the map. The flow runs from a
Claude Code session **inside your target repo**, pointed at a local clone of this harness — so
scouting, filling, and verifying all happen in the repo you'll actually work in.

1. **Once, ever — clone the harness to a stable home you reuse for every project:**
   `git clone <this-repo> ~/agentic-coding-harness`. You never re-clone it per project; one clone serves all
   your repos.
2. **Per repo — open Claude Code in the target repo and point it at that clone:**
   `cd ~/projects/app && claude`, then ask:
   *"Adopt the harness at `~/agentic-coding-harness` into this repo — read its `adopt-harness` skill and follow
   it."* The agent runs the manifest copy (`~/agentic-coding-harness/core/skills/adopt-harness/copy.sh .`),
   then scouts **this** repo and drafts the fills with you — natively, because the session is
   already here.
3. **Fill three slots, then verify:** confirm the drafts for the only repo-specific pieces —
   `AGENTS.md` (the profile; `CLAUDE.md` is a stub that imports it), `make/gate.mk` (your real
   build/test/lint checks), `docs/` (architecture + glossary) — then `make setup && make check` →
   green. Everything else (skills, agents, hooks, rules) is inherited byte-identical, and the
   harness is live in that same session.

**Re-runnable.** Anything a repo fills in — `AGENTS.md`, `CLAUDE.md`, `make/gate.mk`, and the
`docs/` scaffolds — is written only when absent, so re-adoption cannot undo filled-in work. Hook
bindings MERGE (the repo's own entries survive). Everything else is MANAGED: updated by a
three-way comparison against the pristine hash recorded in `.agents/MANIFEST` — an untouched
entry refreshes, a locally-edited one is held and counted, and an entry where BOTH sides changed
is a loud conflict resolved per path with `--resolve <path>=<upstream|local|omit>`. Entries in
`adopt/CRITICAL` fail closed. Never a silent keep, never a silent clobber
(`specs/harness-standardization/research/UPDATE-SEMANTICS-PROPOSAL-2026-08.md`).

The slot contract (defaults, what's optional) is `docs/OVERLAY-CONTRACT.md`; the traveling-file
manifest is `core/skills/adopt-harness/copy.sh`. After adoption the harness travels into
autonomous/cloud runs free via the clone.

## What's in the base (the traveling tree)

| # | Touchpoint | Lives in | What it gives you |
|---|---|---|---|
| 1 | **Always-on profile** | `AGENTS.md` (both providers read it) + `CLAUDE.md` (a stub that `@AGENTS.md`) | definition of done, workflow, risk hotspots |
| 2 | **Path-scoped rules** | `.claude/rules/` | advisory conventions that auto-attach via `paths:` only when matching files are touched |
| 3 | **Quality gate** | `Makefile` (base) + `make/gate.mk` (overlay) | `make check` = the one "done" gate; repo enumerates checks |
| 4 | **Skills** | `.agents/skills/` (`.claude/skills` symlinks to it; Codex scans it natively) | plan (`brainstorm`/`grill`/`write-plan`) · build (`tdd`/`diagnose`/`verify-before-done`/`open-a-pr`) · `handoff` |
| 5 | **Subagents (4)** | `.agents/briefs/` (`.claude/agents/*.md` symlink to them; `.codex/agents/*.toml` point at them) | `scout`/`researcher` (research the design) · `reviewer`/`reviewer-security` (judge the output) |
| 6 | **Hooks** | `.agents/hooks/`, bound by `.claude/settings.local.json` + `.codex/hooks.json` | the guardrails that survive an autonomous run (below) |
| 7 | **MCPs** | `.mcp.json` | ships **empty** — the seed repos add servers into (from `docs/recommended/mcps.md`); secrets are `${VAR}`-referenced, never literal |
| 8 | **Specs / docs scaffolds** | `specs/`, `docs/` | the plan→build handoff and codebase context (architecture · glossary · **ADRs** in `docs/adrs/`); each has a README |

## One harness, two modes
- **Plan mode** (interactive) — `brainstorm → grill → write-plan`; agents `scout`/`researcher`
  resolve the design; gate = the *Definition of Ready*; output = a committed spec in `specs/`.
- **Build mode** (autonomous) — executes the spec (`tdd`/`diagnose`); agents
  `reviewer`/`reviewer-security` judge the output; gate = `make check`; output = a branch.

Both pull the SAME `AGENTS.md`/gate/hotspots — mode = which skills + agents engage. Design lives
in plan; the builder executes and hard-stops on an unresolved design point.

## The guardrails (HOOKS, not permissions — survive a Warren run)
A burrow run spawns `claude --dangerously-skip-permissions`, which **kills `settings.json`
permission rules but NOT hooks**. So every guardrail that must hold in an autonomous run is a hook,
and travels via the clone. All **fail OPEN** if `jq`/`git` is missing — never block work over a
missing tool.

| Hook | Event | Does |
|---|---|---|
| `block-default-branch-commit.sh` | PreToolUse(Bash) | exit 2 on commit/push while on `main`/`master` |
| `block-dangerous-bash.sh` | PreToolUse(Bash) | exit 2 on `rm -rf /`, force-push-to-main, `DROP TABLE`, curl\|sh, … |
| `protect-secrets.sh` | PreToolUse(Read\|Edit\|Write\|apply_patch) | exit 2 on reading/writing `.env`/keys, or writing a literal API key — under **both** providers, including a Codex `apply_patch` |
| `enforce-gate-on-stop.sh` | Stop | re-runs `make check`; blocks "done" until green (circuit-breaker at 5) |
| `ensure-workspace.sh` | SessionStart | creates `.workspace/` if absent; never overwrites `MISSION.md`; must be registered BEFORE the orientation hook |
| `spec-session-orient.sh` | SessionStart | read-only orientation from `.workspace/MISSION.md` — state, next action, spec path, history **filenames**; writes nothing, never blocks |

## Committed vs personal
- **Committed** (team + cloud agents see it; travels into the sandbox): `AGENTS.md`, `CLAUDE.md`,
  `.claude/{settings.json,skills,agents,commands,hooks,rules}`, `.codex/hooks.json`, `.mcp.json`,
  `Makefile`, `make/`, `specs/`, `docs/`.
- **Gitignored** (just you): `.claude/settings.local.json`, `CLAUDE.local.md`.
- **Untracked task memory** (per worktree, dies with it): `.workspace/` — excluded via the
  *global* gitignore, so no repository `.gitignore` mentions it.
- **Global** (all your repos, this machine only): `~/.agents/rules/`, injected by
  `inject-global-rules.sh` only when the session is outside any project.

## Where the "why" lives
Design narrative: `docs/` (`OVERLAY-CONTRACT.md`, `PLAN-MODE.md`, `SOURCES.md`). 
