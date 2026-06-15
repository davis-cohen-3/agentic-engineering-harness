# Recommended subagents — Warren-run harness

Which subagents the harness should carry INSIDE a single Warren run, and which
responsibilities deliberately stay skills/hooks/orchestrator. `[HAVE]` = exists in a real
repo (melting), `[ADD]`/`[KEEP]`/`[CUT]` = recommendation for the standardized base.

## The boundary rule (why this list is short)
Warren (orchestrator) already provides **parallelism** (spawns N runs) and **top-level
isolation** (each run is a sandbox). So a harness subagent earns its slot ONLY if it adds
value at one of two POINTS IN THE PIPELINE — and they split by phase:
```
   research for the PLAN (codebase + outside world) → scout / researcher   [PLAN phase]
   judge the BUILD's OUTPUT (fresh eyes before hand-back) → reviewer / reviewer-security   [BUILD phase]
```
scout/researcher resolve the design UPSTREAM, so the spec carries it and the builder never
designs; the reviewers check the build DOWNSTREAM. The build run itself spawns NO
exploratory subagents — exploration was planning's job. Anything parallel/cross-run =
Warren's job. Anything procedural = a skill. Deterministic-and-enforced = a hook. Keep
subagents to a HANDFUL (3–4).

## Rely on these (the load-bearing roster)

- **`[KEEP]` scout** *(PLAN phase)* — read-only codebase exploration; returns the map, not
  40 files. Produces the codebase facts/pointers that go INTO the spec's design, so the
  builder executes without exploring. Read-noise isolation keeps planning's context clean.
  tools: Read/Grep/Glob + read-only Bash (`git log`/`blame` for history). model: haiku
  (cheap, narrow). No Write.
- **`[KEEP]` researcher** *(PLAN phase)* — scout for the *outside world*: external docs,
  library comparisons, approach trade-offs — informs the design before it's frozen in the
  spec. Kept separate because it carries web tools the internal scout shouldn't have.
  tools: +WebSearch/WebFetch + Bash for read-only `gh` (read a library's repo/releases/issues
  structured, not via HTML). model: haiku.
- **`[KEEP]` reviewer** — adversarial fresh-eyes on the diff BEFORE hand-back. Warren's whole
  model is "push a branch → human reviews"; an automated reviewer that runs the gate + audits
  the diff is the cheapest place to catch problems. Merge quality + spec lenses here
  (both answer "is this good / on-intent?"). tools: Read/Grep/Glob, Bash(read-only/test),
  git diff. **No Write.** model: sonnet.
- **`[KEEP]` reviewer-security** — the one specialized adversarial gate worth splitting out.
  Maps to the risk hotspots (auth · payments · data-exposure). High stakes justify its own
  lens (OWASP, input validation, authz). tools: Read/Grep/Glob. model: sonnet.
  Extend to cover migrations · outbound-send · prod-deploy if you want one consolidated
  "risk-auditor" instead — do NOT make five separate hotspot agents.

## Deliberately NOT subagents (and where they go instead)

- **`[CUT]` builder → the run itself.** Under Warren the RUN is the builder; a sub-builder
  rebuilds Warren's task-decomposition inside the harness (the swarm pattern Warren retreated
  from). Attach its skills (tdd/test/migrations/frontend) to the run, not a sub-agent.
- **`[CUT]` spec-loader → nothing (fully removed).** "Read the spec, orient the run" is
  context-loading, not fresh-eyes work — no agent justified. We briefly made it a *skill*, then
  cut that too: the orchestrator's dispatch prompt points the run at its spec, and CLAUDE.md's
  build loop carries the "hard-stop on an unready spec" rule. A skill there just restated both.
- **test-writer → skill.** You want to see + iterate on tests; conversational, shared context.
- **planner → orchestrator (plan-run).** Heavy planning is a Warren plan-run; light in-run
  scoping is inline or the scout. Don't duplicate at the harness layer.
- **doc-writer / commit-message / formatter / simplifier → skills or hooks.** No separate
  context needed.
- **per-language / per-framework specialists → CLAUDE.md + skills.** Subagents don't scale
  here (each is a routing decision + a fresh context = tax). Skills scale; subagents don't.

## Audit result (melting's 7 → 4)
scout ✅ · researcher ✅ · reviewer-security ✅ · reviewer-quality + reviewer-spec → merge to
**reviewer** ✅ · builder ❌ (→ the run) · spec-loader ❌ (→ orchestrator dispatch + CLAUDE.md;
not even a skill). Net: 7 standing agents → 4, lower context tax, same coverage.

## Tool/model discipline (carried from melting, worth standardizing)
- Read-only agents (scout/researcher/reviewers) get **no Write** — least-privilege; a reviewer
  literally can't "helpfully" edit your code. Where they get Bash (scout `git`, researcher `gh`),
  it's for read-only history/repo access only — never to mutate the tree.
- Narrow read jobs → **haiku** (scout/researcher); judgment jobs → **sonnet** (reviewers).
- `description` is the routing signal — write it like a skill trigger.
