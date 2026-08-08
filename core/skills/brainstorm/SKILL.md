---
name: brainstorm
description: >-
  Use at the START of a non-trivial (T3) task to explore the
  solution space CONVERSATIONALLY and pick an APPROACH before any code or spec —
  a quick back-and-forth to understand the problem, then 2-3 real options with
  trade-offs, then one pick. Trigger on "how should we approach", "what are the
  options for", or a genuine design fork. Skip for T0/T1 and obvious-approach T2.
---

# Brainstorm — figure out what we want, and how

The #1 failure mode is misalignment *before* code. This is the **divergent** front of planning:
ideate on *what we actually want* (the problem/goal — a rough PRD) and *which approach* gets us
there. You are PRESENT and interactive, so this is a **conversation, not a report** (the
obra/superpowers brainstorming pattern).

STARTER_CHARACTER = 🧠 (begin brainstorm replies with it)
When starting, announce: `🧠 Brainstorm — Phase 1: Discuss`

## Gate
Do NOT advance to `grill-me`/`write-plan`, scaffold, or write any code until you've talked
the problem through, laid out approach options, and I've picked one — the "too simple to need
a design" reflex is exactly where unexamined assumptions cause the most rework.

## Scope — the WHAT and the WHICH, divergently
Two things, both high-altitude: *what we actually want* (the problem/goal — a rough PRD) and
*which approach* gets us there (you propose directions out loud, I choose). Stay at the altitude
of *"what are we solving / which way do we go"* — NOT detail-nailing (that's `grill-me`,
convergent) and NOT a codebase audit (that's the `scout` agent). Run order: brainstorm →
grill-me → write-plan (at obvious-approach T2, skip brainstorm and start at `grill-me`).

## Phase 1 — Discuss   (conversational; NO code tools)
Understand the problem space through quick back-and-forth, BEFORE proposing any solution.
- **Short turns, not an essay.** Ask, react, ask again — keep the loop fast.
- **Challenge my framing:** play devil's advocate, surface constraints, probe edge cases,
  question whether we're even solving the right problem.
- **No Read/Grep/Glob/web here** — keep it idea-level and quick; defer evidence-gathering to
  Phase 2's targeted pulls.
- **Capture as you go:** log `IDEA` / `QUESTION` / `CONSTRAINT` entries under the
  **Brainstorm thread** section of the spec's `thoughts.md` (shape: `specs/templates/t2/spec.thoughts.md`)
  as they surface.
- **Transition:** when the problem feels well understood, say so and check —
  *"Ready to lay out the options?"* Then announce `🧠 Phase 2: Diverge`.

## Phase 2 — Diverge   (the options)
1. **Restate the goal** in one sentence; confirm it before diverging.
2. **Generate 2-3 genuinely different approaches** — not one idea with variations. For each:
   core idea · what it's good at · main cost/risk · what it forecloses.
3. **Pull in `researcher`/`scout`** ONLY for a specific unknown an option hinges on (an
   external API, an unverified codebase assumption) — a targeted check, not a survey.

## Phase 3 — Converge   (recommend + pick)
1. **Recommend one** with the one-line why; name the runner-up's single best idea worth
   grafting into the winner.
2. **Get my pick** — do not silently proceed on your favorite.
3. **Log the `DECISION`** under `thoughts.md`'s **Brainstorm thread**: the chosen approach
   *and why the others lost*.

## Output
A rough synthesis — the problem/goal we agreed on **plus** the chosen approach (and the
options/trade-offs that lost) — captured in `thoughts.md`. Think of it as a **rough PRD**: not
yet nailed down (that's `grill-me`), not yet a spec (that's `write-plan`), but the aligned
starting point both build on. This feeds `grill-me` → `write-plan` (which synthesizes the thread
into the spec). Keep it tight — a decision, not a survey.
