# agentic-coding-harness

A **portable Claude Code harness base**: repo-agnostic skills, agents, hooks, and a definition
of done that drops into any repository and travels into an autonomous sandbox (Warren/burrow)
**free via the git clone**.

The governing idea: the QUALITY of an agent's planning/building/reviewing lives in the
**harness**, not the orchestrator. This repo is that harness, made concrete.

## Two layers
- **The portable harness** — everything that travels into a target repo. The exact set is pinned
  by the manifest in `.claude/skills/adopt-harness/copy.sh`.
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
   it."* The agent runs the manifest copy (`~/agentic-coding-harness/.claude/skills/adopt-harness/copy.sh .`),
   then scouts **this** repo and drafts the fills with you — natively, because the session is
   already here.
3. **Fill three slots, then verify:** confirm the drafts for the only repo-specific pieces —
   `AGENTS.md` (the profile; `CLAUDE.md` is a stub that imports it), `make/gate.mk` (your real
   build/test/lint checks), `docs/` (architecture + glossary) — then `make setup && make check` →
   green. Everything else (skills, agents, hooks, rules) is inherited byte-identical, and the
   harness is live in that same session.

**Adopt once per repo.** `copy.sh` never clobbers an existing `CLAUDE.md` or `make/gate.mk`, but the
rest of the tree is a recursive copy — a blind re-run can overwrite other filled files. Onboarding a
repo that already has its own `.claude/` deserves a careful look first, not a re-run.

The slot contract (defaults, what's optional) is `docs/OVERLAY-CONTRACT.md`; the traveling-file
manifest is `.claude/skills/adopt-harness/copy.sh`. After adoption the harness travels into
autonomous/cloud runs free via the clone.

## What's in the base (the traveling tree)

| # | Touchpoint | Lives in | What it gives you |
|---|---|---|---|
| 1 | **Always-on profile** | `AGENTS.md` (both providers read it) + `CLAUDE.md` (a stub that `@AGENTS.md`) | definition of done, workflow, risk hotspots |
| 2 | **Path-scoped rules** | `.claude/rules/` | advisory conventions that auto-attach via `paths:` only when matching files are touched |
| 3 | **Quality gate** | `Makefile` (base) + `make/gate.mk` (overlay) | `make check` = the one "done" gate; repo enumerates checks |
| 4 | **Skills** | `.claude/skills/` | plan (`brainstorm`/`grill`/`write-plan`) · build (`tdd`/`diagnose`/`verify-before-done`/`open-a-pr`) · `handoff` |
| 5 | **Subagents (4)** | `.claude/agents/` | `scout`/`researcher` (research the design) · `reviewer`/`reviewer-security` (judge the output) |
| 6 | **Hooks** | `.claude/settings.json` + `.claude/hooks/` | the guardrails that survive an autonomous run (below) |
| 7 | **MCPs** | `.mcp.json` | ships **empty** — the seed repos add servers into (from `docs/recommended/mcps.md`); secrets are `${VAR}`-referenced, never literal |
| 8 | **Specs / docs scaffolds** | `specs/`, `agent_docs/` | the plan→build handoff and codebase context (architecture · glossary · **ADRs** in `agent_docs/adr/`); each has a README |

## One harness, two modes
- **Plan mode** (interactive) — `brainstorm → grill-me → write-plan`; agents `scout`/`researcher`
  resolve the design; gate = the *Definition of Ready*; output = a committed spec in `specs/`.
- **Build mode** (autonomous) — executes the spec (`tdd`/`diagnose`); agents
  `reviewer`/`reviewer-security` judge the output; gate = `make check`; output = a branch.

Both pull the SAME `CLAUDE.md`/gate/hotspots — mode = which skills + agents engage. Design lives
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
| `protect-secrets.sh` | PreToolUse(Read\|Edit\|Write) | exit 2 on reading/writing `.env`/keys, or writing a literal API key |
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
