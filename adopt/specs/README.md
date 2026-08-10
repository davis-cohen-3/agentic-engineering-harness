# specs/ — the plan→build handoff

A spec is what **replaces you in an autonomous build run**. The builder reads it and cannot ask a
question, so the bar is *survives-your-absence*. Specs are **committed** — they travel into a
sandbox clone, so a build run can read the one it was pointed at.

## Two modes — design in plan, execute in build
**Plan mode** is interactive: it resolves the design and writes the spec. **Build mode** is
autonomous: it executes the spec and does **not** redesign.

- `brainstorm` → `grill` → `write-plan` produce the spec.
- `tdd` / `diagnose` / `verify-before-done` / `open-a-pr` execute it.
- **One run builds one task.** A build is never split across sub-agents.
- **Spec not `ready`, or an unresolved design question? HARD-STOP and flag it.** Do not invent
  the design — hand back "blocked: design gap at <X>". This is the rule the whole model rests on.

## Task tiers — they size the response, nothing else
| Tier | Work | Spec shape |
| --- | --- | --- |
| **T0** | trivial — a typo, a constant, a one-line fix | none |
| **T1** | small, obvious approach | a few lines: goal + acceptance + one pointer (`templates/t1/`) |
| **T2** | a standard feature | the full single-file spec (`templates/t2/`) |
| **T3** | a multi-task epic | an `<epic>/` folder: index README + ordered sub-specs (`templates/t3/`) |

`make check`, risk-review on a hotspot, and `verify-before-done` **never scale down** — no tier
exempts them.

## Where the thinking lives before it becomes a spec
Planning output is **not** committed scratch. It accumulates in the worktree's untracked
`.workspace/`, and the spec is what graduates out of it:

```text
.workspace/LOG.md  →  specs/<slug>.md                     (T0–T2)
.workspace/LOG.md  →  specs/<epic>/README.md + 01-*.md    (T3)
```

- **`.workspace/LOG.md`** — the ordered ledger of `DECISION` / `QUESTION` entries with their
  evidence, rejected alternatives, and consequences. Appended to as you brainstorm and grill.
  It is the direct input to `write-plan`.
- **`.workspace/history/`** — immutable `handoff` and `finding` records.
- Both are **untracked and disposable**; they die with the worktree.

**There is no scoping document.** Curated framing lives inside the spec, in sections it already
has: `## Problem / Solution / User stories`, `## Out of scope`, `## Resolved decisions`.

**Retired outright** — if you find one of these, it is a leftover:

| Surface | Replaced by |
| --- | --- |
| `specs/<slug>.thoughts.md` | `.workspace/LOG.md` |
| `specs/<slug>.sessions/` | `.workspace/history/<utc>-handoff-<slug>.md` |
| `.context/<slug>.md` | `.workspace/LOG.md` |
| `specs/<slug>.scoping.md` | never created |

## Which spec a worktree is on — one field, no ceremony
`.workspace/MISSION.md`'s `spec:` field records a repo-relative path, written like any other
line in the file. `write-plan` sets it as it writes the spec. In a T3, the build worktrees are
cut *after* `write-plan` ran in the planning worktree, so **each build worktree's `spec:` is set
by the developer or the first session** — it is the one write with no automated owner.

"Bind" is not vocabulary here. There is no bind command, no `make work`, no `.claude/active-spec`,
no source-commit pin, and no drift detection. Repointing is editing the field.

## Cross-worktree sharing — merge the spec first
Worktrees branch from `origin/main`, so a spec must be **merged**, not merely committed, before
parallel build worktrees are cut. For a T3 that makes the sequence:

```text
1  cut a planning worktree            plan/<slug>, off origin/main
2  brainstorm → grill                 → .workspace/LOG.md
3  write-plan                         → specs/<epic>/README.md + 01-*.md
4  spec-only PR → merge to main
5  cut N build worktrees              each fresh from origin/main
6  set each MISSION's spec: field
7  build in parallel
```

T0–T2 need none of this: cut a worktree, build, ship.

## Layout
```text
specs/
  README.md                          this file — the convention
  templates/                         worked examples, one folder per tier
    t1/spec.md                       T1 — goal + acceptance + one pointer, nothing more
    t2/spec.md                       T2 — the full spec shape (field labels = the guidance)
    t3/                              T3 — a DECOMPOSED epic (the folder IS the spec)
      README.md                      the epic index: shared context + ordered task list
      01-queue-table.md              sub-spec (one build run); 02, 03 follow with deps
      02-worker.md
      03-retry-dlq.md
  <slug>.md                          ← your real spec (from templates/t1/ or t2/)
  <epic>/                            ← a T3 epic (from templates/t3/)
```

`templates/` only keeps the examples out of the top level. A real T0–T2 spec is a single flat
file; only a T3 epic is a folder.

## Lifecycle — status frontmatter, not folders
Each spec carries `status:` in frontmatter, moving `draft → ready → building → done`:

- **draft** — still being written or grilled.
- **ready** — passed the Definition of Ready: **no open decisions remain**. Safe to hand to a
  build run. Never flip to `ready` over a guess.
- **building** — a run is executing it.
- **done** — shipped and verified.

Status lives in frontmatter rather than `active/`+`done/` folders so a spec's history stays in
one file and `git log` is the audit trail.

## The bar — when is a spec `ready`?
Only when it passes the **Definition of Ready**, the checklist owned by the `write-plan` skill.
The load-bearing box is **no open decisions** — the survives-your-absence test.

## What a spec is not
The **conclusion, not the journey**. Repo context is *linked* from `docs/`, never pasted in. The
planning path stays in `.workspace/LOG.md` and is not read by the build.
