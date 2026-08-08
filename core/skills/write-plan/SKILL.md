---
name: write-plan
description: >-
  Use after grilling to turn the conversation into a written,
  decomposed spec that an autonomous build run can execute without you in the
  room. Decomposes into context-sized, ordered tasks and fills the Warren-ready
  spec template. Trigger on "write the plan/spec", "decompose this", or after
  grill-me. The output must pass the Definition of Ready before hand-off.
---

# Write-plan — turn alignment into a hand-off spec

STARTER_CHARACTER = 📐 — open each reply with it while this skill is active.

This is where **decomposition happens** (we chose Option A: planning decomposes,
the orchestrator only executes). The spec is the handoff artifact between the
present architect and the absent builder.

## How to work
1. **Ingest the planning thread — you SYNTHESIZE, you don't re-interview.** The context you
   write the spec FROM already exists: the `brainstorm` approach (the option picked + why),
   the `grill-me` answers, and the `specs/<slug>.thoughts.md` thread (typed DECISION / QUESTION
   / IDEA / CONSTRAINT entries). That thread is the raw material; the spec is its resolved
   conclusion. Pull **Resolved decisions** and **Out of scope** straight from it. If any thread
   `QUESTION` is still open, the spec is NOT ready — go back to `grill-me`, don't guess.
2. **Resolve the design** — the load-bearing planning work. Use `scout` (codebase) and
   `researcher` (external) — grounded in `agent_docs/` (architecture + glossary) — to settle
   the approach + data model + contracts + integration points + error handling + **the test
   seam** (prefer an existing, highest-possible seam + a prior-art test to mirror), and fill
   **Approach & design** completely. The builder EXECUTES
   this and hard-stops on any gap, so leave none. (scout/researcher are PLAN-phase agents;
   the build run does not get to design.)
3. **Decompose** against that design into context-sized tasks — each one a unit a single
   build run can finish. Order them; note dependencies. Default **sequential**
   (task N+1 may need task N's output); only mark tasks parallel if proven independent.
4. **Write the spec into `specs/`** (the committed home — it travels into the sandbox).
   Copy `specs/templates/t2/spec.md` → `specs/<slug>.md` (T1: `templates/t1/spec.md`; T3: copy
   `specs/templates/t3/` → a `specs/<epic>/` subdir) and replace the content;
   `specs/README.md` has the convention + lifecycle. Every field
   pre-answers a builder's question — fill them all, or say why N/A.
   Enumerate **Key user stories** (each is a candidate acceptance criterion — a completeness
   check), and carry **Out of scope** + **Resolved decisions** over from the planning thread
   (step 1). Set `status: draft` until it passes the Definition of Ready, then `status: ready`.
   **Promote durable decisions:** if a Resolved decision is repo-level + hard-to-reverse + a
   real trade-off (not task-local), write it as an ADR in `agent_docs/adr/` (copy
   `0000-template.md`) and *reference* it from the spec instead of burying it — see
   `agent_docs/adr/README.md`.
5. **Right-size:** collapse the template for T1 (goal + acceptance + one pointer);
   use the full form for T2/T3. Don't bloat a small task into a max spec — but
   **risk hotspots, the gate, and verify-before-done never scale down**.
6. **Self-review with fresh eyes** (pattern from obra/superpowers writing-plans): scan the
   spec for **placeholders** (any TBD/TODO/"figure out later" = not ready — the builder
   can't fill it), internal **contradictions**, **ambiguity** (could a requirement be read
   two ways? pick one, make it explicit), and **scope** (still one coherent unit, or split?).
   Fix inline.
7. **Check the Definition of Ready** before declaring the spec done:
   ```
   ☐ Approach & design RESOLVED — no open design question the builder would hit
   ☐ every acceptance criterion is objective / testable
   ☐ decomposed into context-sized tasks with dependencies noted
   ☐ scope boundaries explicit (out-of-scope listed)
   ☐ NO unresolved questions / open decisions remain   ← survives-your-absence test
   ☐ risk hotspots flagged
   ☐ verification method stated
   ```
   (A build run will hard-stop and flag any design gap — that's a planning failure,
   not a build problem.)

## Output
A finished spec (the template, filled). This is the build-mode input — the orchestrator's
dispatch prompt points each build run at it; the run reads it and executes (no loader skill).
Hand it back; do not start building from plan mode.
