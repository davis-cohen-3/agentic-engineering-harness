# specs/ — the plan→build handoff artifacts

A spec is what replaces YOU in an autonomous build run. Plan mode
(`brainstorm → grill-me → write-plan`) produces specs here; build runs consume them (the
orchestrator's dispatch prompt points each run at its spec). Specs are **committed** — they
travel into the sandbox via the clone, so a build run can read the one it's assigned.

## Where context lives (worktree ↔ spec ↔ shared docs)
A unit of work = a **task branch**, checked out in isolation — a local **git worktree** when
you work by hand, or a **burrow sandbox clone** in an autonomous run. Same thing: one isolated
checkout on one branch. Context splits into two halves by lifetime:

- **Task-local — travels WITH the branch, in the spec folder.** `<slug>.md` (the plan, read by
  the build), `<slug>.thoughts.md` (the planning path — plan-only, NOT read by the build), and
  `<slug>.sessions/` (mid-build session-to-session state). This is the memory *of this one piece
  of work*; it lives and dies with the branch.
- **Worktree-local scratch — does NOT travel, gitignored.** `.context/<slug>.md` — an
  uncommitted notepad: the messy, real-time working buffer for *this checkout*, spanning
  plan→build→test (dead-ends, raw test output, open threads). It survives compaction (the
  `SessionStart` hook re-surfaces its path on every start/resume/compact) but never the merge —
  it's the **scratch inbox**, not a source of truth. Anything durable graduates OUT of it into
  the committed artifacts above; the buffer is then discarded. Detailed in the companions section.
- **Repo-level — SHARED, referenced not copied.** `agent_docs/architecture.md` + `glossary.md`
  (current system shape + domain language) and `agent_docs/adr/` (durable, append-only
  decisions). Every branch sees the same copy; a spec *links* these, never duplicates them.

So the spec folder holds *this task's* memory; `agent_docs/` + ADRs hold *the repo's*.

**Binding a worktree to its spec.** Each worktree records the exact spec it's on in a gitignored
pointer, `.claude/active-spec` (one line — the path, e.g. `specs/<epic>/02-gate.md`). Set it
**eagerly** when work begins — `make work SPEC=specs/<slug>.md` by hand, or the orchestrator
writes it at clone for an autonomous run (it already has the spec in the dispatch prompt). The
`SessionStart` hook (`.claude/hooks/spec-session-orient.sh`) reads that pointer and injects
"here's your spec" into every session — local, resumed, or post-compaction — so you never hand it
the path. With no pointer it falls back to the branch name (`specs/<branch>.md|/`, then the last
segment) and, on a hit, **self-binds** by writing the pointer for you — so a forgotten eager bind
still re-anchors and stays stable across renames. The explicit pointer is what covers T3 epics and
branches whose name ≠ the spec slug. `.claude/rules/specs.md` then reinforces the spec conventions
the moment a spec file is opened.

## Layout
The top level holds this README and your real specs. Everything illustrative lives in
`templates/`, **one folder per tier** (all on a single webhook theme so they read together) —
copy a tier's contents out & adapt:

```
specs/
  README.md                          this file — the convention
  templates/                         worked examples, one folder per tier
    t1/
      spec.md                        T1 — the FLOOR: goal + acceptance + one pointer, nothing more
      spec.context.md                the scratch notepad (gitignored in real use; example only)
    t2/
      spec.md                        T2 — the full spec shape (filled; field labels = the guidance)
      spec.thoughts.md               the planning thread (optional companion)
      spec.sessions/001_*.md         a sample mid-build session handoff
      spec.context.md                the scratch notepad (gitignored in real use; example only)
    t3/                              T3 — a DECOMPOSED epic (the folder IS the spec)
      README.md                      the epic index: shared context + ordered task list
      01-queue-table.md              sub-spec (one build run); 02, 03 follow with deps
      01-queue-table.context.md      per-sub-spec scratch notepad (gitignored in real use; example)
      02-worker.md
      03-retry-dlq.md
  <slug>.md                          ← your real spec (copied from templates/t1/ or t2/)
  <slug>.thoughts.md                 ← optional, co-located (committed)
  <slug>.sessions/NNN_*.md           ← optional, co-located (committed)
  <epic>/                            ← a T3 epic (copied from templates/t3/)
  .context/<slug>.md                 ← scratch notepad — GITIGNORED, auto-created by the hook
```

A single (T0–T2) spec is **flat sibling files** named for the work (`rate-limit-webhooks.md` +
its optional committed `.thoughts.md` / `.sessions/`, plus the gitignored `.context/<slug>.md`
scratch notepad). `templates/` is just the box that keeps the examples
out of the top level — in real use a single spec's files are siblings, not under a folder; only a
T3 epic is itself a folder.

## The companion artifacts (each stated once, here)
The first three are **committed** (curated, travel with the branch); the fourth is **uncommitted**
scratch (gitignored, dies with the worktree).
- **`<slug>.md`** — the spec. The conclusion: what to build, fields pre-answering a builder's
  question. Read by the build run.
- **`<slug>.thoughts.md`** — *optional* planning thread. HOW you got there: decisions, ideas,
  rejected alternatives, as typed dated entries (**IDEA · DECISION · RESEARCH · QUESTION ·
  CONSTRAINT · INSIGHT**). Two phase sections (Brainstorm / Grilling) but **one chronological
  number line**, so a grilling `DECISION` can close a brainstorm `QUESTION` by id. Durable
  reference — *why did we pick X, what did we reject?* — NOT read by the build. Skip it for
  trivial work. (We deliberately did NOT split the spec into requirements/design/tasks files —
  one doc + this thread is the right weight.)
- **`<slug>.sessions/NNN_*.md`** — *optional* mid-execution session handoffs, written by the
  `handoff` skill (its format lives in that skill). Carries session-to-session state WITHIN
  one spec — distinct from the plan→build handoff the spec itself is.
- **`.context/<slug>.md`** — *uncommitted* scratch notepad (gitignored), the **scratch inbox** for
  this worktree. Free-form, no schema: in-flight thinking across plan→build→test — dead-ends, raw
  test output, "still need to check X", half-formed observations. The `SessionStart` hook ensures
  it exists and re-surfaces its path on every start/resume/compact, so working memory survives
  compaction. **Rule: it is never a source of truth.** It captures fast and loose; anything that
  proves durable graduates into the right committed home — a decision/rationale into
  `<slug>.thoughts.md`, a build-resume state into `<slug>.sessions/`, a change to *what to build*
  into `<slug>.md` — and the notepad is discarded at merge. Distinct from `.thoughts.md` (which is
  committed, curated, and plan-phase) on the commit axis: this is the raw buffer those curated
  artifacts are drained *from*.

## Lifecycle — status frontmatter, not folders
Each spec carries `status:` in frontmatter; it moves `draft → ready → building → done`:
- **draft** — still being written / grilled.
- **ready** — passed the Definition of Ready (NO open decisions): safe to hand to a build run.
- **building** — a run is executing it.
- **done** — shipped + verified.

(Status in frontmatter, not `active/`+`done/` folders, so a spec's history stays in one file
and `git log` is the audit trail. Switch to folders only if you outgrow this.)

## The bar — when is a spec `ready`?
Only when it passes the **Definition of Ready**, the checklist owned by the `write-plan`
skill. The load-bearing box is **no open decisions** — the survives-your-absence test.

## Right-sizing
- **T0/T1** — a few lines (goal + acceptance + one pointer); a single `<slug>.md`
  (worked: `templates/t1/`).
- **T2** — the full spec shape, one file (worked: `templates/t2/`).
- **T3** — an `<epic>/` subdir, decomposed into ordered per-task specs behind an index README;
  uniquely, it then executes as **multiple build runs — one per sub-spec**, dispatched in
  dependency order (T0–T2 are a single run). Decomposition stays a single plan pass
  (the `write-plan` skill resolves it before hand-off); dispatching the ordered sub-specs is
  the orchestrator's job, not the harness's. (worked: `templates/t3/`)
(Risk hotspots, the gate, and verify-before-done never scale down — the `CLAUDE.md` floor.)
