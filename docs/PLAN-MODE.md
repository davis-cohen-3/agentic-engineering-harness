# Plan mode — why the plan half is shaped this way

> **Design narrative, not agent-loaded context.** This explains *why* the plan/build split
> exists; it does NOT carry the operational steps. Those live in the skills that travel into
> every repo (`brainstorm` / `grill-me` / `write-plan` + the DoR they enforce), in
> `specs/README.md` (lifecycle + right-sizing) and `specs/templates/t2/spec.md` (the fields), and in
> `.claude/FLOOR.md` (the never-scale-down floor). An agent never needs to read this to plan.

## What planning is — aligning the human and the agent
Planning is the **alignment step between the human engineer and the coding agent**: it turns
intent in your head into a spec the agent can execute *without you in the room*. It spans the
full size range — a one-line fix, a feature, or a multi-task epic; what scales with size is the
*depth* of planning (decision 3), never whether you align.

**The crisp line between the modes: plan is human-in-the-loop, build is human-out-of-the-loop.**
In plan you are **present** — the agent can ask you anything. In a build run you are **absent** —
autonomous, sandboxed; it *cannot ask a single question*. Everything below follows from that.

## Governing principle: a spec is "ready" when it survives your absence
Because the builder is absent, the spec is what **replaces you in the room** — it must
pre-answer every question the absent builder would otherwise guess at. Planning's real job is to
extract those answers out of your head *before you leave*. This is why alignment is front-loaded:
you can't fix a misaligned autonomous run mid-flight.

## The alignment funnel: rough → sharp → formal
Three skills converge intent into a hand-off spec, each tightening the last:
- **`brainstorm`** (diverge) — ideate on *what we actually want* and *which approach*, capturing
  the journey (ideas, constraints, rejected options) in `thoughts.md`. Output ≈ a **rough PRD**:
  the problem + the chosen direction.
- **`grill-me`** (converge) — interview you relentlessly until that rough synthesis is nailed
  down: every branch resolved, every ambiguity killed.
- **`write-plan`** (formalize) — synthesize the thread into the committed spec the build run
  executes.

(The skills own the operational steps; this is just the shape of the convergence. Lower tiers
collapse the funnel — T0/T1 may skip straight to a thin spec; see decision 3.)

Everything below is a consequence of the governing principle.

## The four decisions

**1. One harness, two modes — not two harnesses.** Plan and build SHARE the expensive stuff
(stack facts, structure map, conventions, hotspots, the gate = `CLAUDE.md`) and differ only in
cheap stuff (which skills load, interactive vs autonomous posture). Forking into two
`CLAUDE.md`s would let them drift — the same single-source reason `/ship` delegates to
`open-a-pr`. So: one base config, mode = which skills + which run type. (Split only if planning
ever lives in a physically separate repo from the code; it doesn't here.)

**2. Decomposition happens in plan, not in the orchestrator (Option A).** `write-plan` resolves
the design and decomposes into ordered, context-sized tasks *before* hand-off; the orchestrator
executes a pre-decomposed spec, it never invents the decomposition. This keeps Warren a reliable
dispatcher rather than an autonomous architect — which de-risks the whole orchestration layer.

**3. SIZE and RISK are independent axes.** Planning *depth* scales with size (surface area +
ambiguity); risk is a separate dial that escalates *care* and is never waived. The subtlety this
guards against: a 1-line auth/migration change is tiny-surface but max-risk → small spec, full
risk-review.
```
                RISK (touches hotspot?)  low ─────► high
   SIZE  small  │  T0/T1 just build      │  small but CAREFUL (full risk-review) │
         large  │  T2 full spec          │  T3 spec + brainstorm                 │
```
(The T0–T3 tier ladder and the triage front-door that route on this live in
`specs/README.md` → Right-sizing. The invariant that keeps right-sizing ≠ corner-cutting:
you may skip the *planning*, never *"done."* The three that never scale down — gate ·
risk-review · verify-before-done — are owned by the `CLAUDE.md` floor.)

**4. The Definition of Ready is the planning twin of the quality gate.** Build has a quality
gate ("is the code done?" → `make check`); plan has the mirror, a Definition of Ready ("is the
spec safe to hand off?"). The load-bearing box is *"no open decisions remain"* — the governing
principle made into a gate. The checklist itself is owned by the `write-plan` skill (single
source, can't drift); a build run hard-stops on any design gap, so an unresolved DoR is a
*planning* failure caught late.

## The bookends
Your judgment lives in the two ends of the workday — **architecting the spec** (plan) and
**reviewing the branch** (build output); the middle is the machine. Each mode has a gate that
defines "done" for that mode (the `CLAUDE.md` Definition-of-done principle, applied twice):
plan → Definition of Ready → a spec with the design RESOLVED; build → `make check` → a branch
with the design EXECUTED. The spec is the handoff between them.

## Pointer
How the orchestrator actually consumes this spec format — dispatching a decomposed spec into
sequential build-runs, threading task N's output into task N+1 — is an **orchestrator** decision,
not a harness one. It's tracked in the orchestrator/Warren requirements kept outside this repo;
the harness scope ends at the spec hand-off.
