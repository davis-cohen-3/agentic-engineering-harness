# Harness floor — INHERITED, do not edit per repo

> This file is the **base harness floor**: repo-agnostic rules that must fire on EVERY task in
> EVERY repo. It is single-sourced — the `adopt-harness` skill (in the base) ships it
> **byte-identical** into each repo; edit it only in the base, never per repo. Repo-specific
> facts (stack, structure, commands, tuned hotspots) live in the importing `CLAUDE.md` PROFILE.
>
> Always-on context is a tax on every task — keep only what is needed BROADLY and ALWAYS.
> Conditional/rare knowledge → a skill (`.claude/skills/`). Path-scoped conventions → a
> `.claude/rules/` file with `paths:`. Per-task knowledge → say it in the prompt. Personal taste
> → `~/.claude/CLAUDE.md`.

## Definition of done
A change is done ONLY when ALL of:
  1. `make check` passes (the gate — the code is valid).
  2. You RAN the change and watched the intended behavior work (`verify-before-done`) —
     compiling is not working.
  3. You reviewed your own diff against the approved plan.
Produce a verification report (what you ran, what you saw, plan items done/skipped). If any step
is skipped or fails, say so plainly with the output. **Never claim done on unrun code.**
The Stop-gate hook enforces only step 1 (`make check` green); steps 2–3 are on you — a green gate
proves the code is *valid*, NOT that you *ran* it, so it is never sufficient evidence of "done".

## Workflow
- Work on a **task branch** — never commit to the default branch (a hook enforces this). Branch
  per task.
- Ship via **PR** (`/ship` → `open-a-pr`). Commit/push only when asked.
- Match the surrounding code's structure and idiom so review is about logic, not formatting.
  **Prefer minimal-to-no comments** — comment only the non-obvious *why*, never the *what*.

## Two modes — design in plan, execute in build
PLAN mode (interactive) resolves the design and writes the spec; BUILD mode (autonomous)
executes it and does NOT redesign. The skills carry the operational steps —
`brainstorm`/`grill-me`/`write-plan` (plan) · `tdd`/`diagnose`/`verify-before-done`/`open-a-pr`
(build) — and agents (`scout`/`researcher` · `reviewer`/`reviewer-security`) fire per their own
triggers; `specs/README.md` holds the spec lifecycle.
- **Task tiers (`T0`–`T3`) size the response**, smallest→largest: T0 trivial · T1 small · T2
  standard feature · T3 multi-task epic. Full definitions + spec shapes live in `specs/README.md`.
- **Building from a spec? Bind the worktree to it** — `make work SPEC=specs/<slug>.md` (the
  `SessionStart` hook also self-binds from the branch name when you don't), so resumed and
  post-compaction sessions re-anchor without you re-supplying the path.
- **One run builds one task; the build is NEVER split across sub-agents.**
- **Spec not `ready`, or an unresolved design question? HARD-STOP and flag it** — do not invent
  the design; hand back "blocked: design gap at <X>".
- `make check`, risk-review (if a hotspot), and `verify-before-done` **never scale down.**

## Risk hotspots — slow down, engage `reviewer-security`, never skip review
Touching any of these escalates *care* regardless of task size. Convergent base set:
**migrations · auth · payments · outbound-send (email/LLM/webhooks) · prod deploy · spend.**
Your repo's tuned hotspots are in the PROFILE.
- Secrets are never committed; `.mcp.json` holds `${VAR}` references, never values.

## Skill markers
Every skill declares a `STARTER_CHARACTER`. While a skill is active, **open each reply with its
marker** — a visible confirmation the intended skill loaded (and, for phased skills like `tdd`,
*which* phase: 🔴 red / 🌱 green / 🌀 refactor). No skill active → no marker.
