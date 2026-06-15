# agent_docs/adr/ — Architecture Decision Records

Durable, repo-level decision memory: one file per significant decision, in order. An ADR
answers *"why is the system built this way?"* for whoever (human or agent) later wants to
undo it. Distinct from a spec's **Resolved decisions** (task-local, consumed once) and a
spec's `thoughts.md` (one task's planning path) — see `../README.md` for the three layers.

## When a decision earns an ADR
Only when it's **hard to reverse + surprising + a real trade-off**. Easy-to-reverse or obvious
decisions stay in the spec — an ADR for them is noise. Qualifying examples: "money is integer
cents, never floats", "auth is stateless JWT, not sessions", "orders use optimistic locking,
accepting retry-on-conflict".

## How one gets written — in plan mode
While `write-plan` synthesizes a spec's Resolved decisions, any that clears the bar above is
promoted here instead of buried in the spec; the spec then references it. A build run never
writes one — `diagnose` may *flag* that an architectural decision is needed, but that routes
back to plan mode (architecture is a design decision, not an autonomous edit).

## Lifecycle — append-only
- Number monotonically: `NNNN-slug.md`, zero-padded (`ls` this dir → next; start `0001`).
- `status: accepted` once decided. **Never edit an accepted ADR's decision** — if the call
  changes, write a NEW ADR that supersedes it (`status: superseded-by NNNN` on the old,
  `supersedes: NNNN` on the new). The log is the audit trail — same instinct as append-only
  migrations.
- Copy `0000-template.md` to start.
