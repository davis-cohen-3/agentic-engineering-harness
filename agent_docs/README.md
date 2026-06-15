# agent_docs/ — codebase context for agents

The docs an agent reads to understand **this** codebase: how it's built, the domain
language, the conventions. Skills and agents consult this directory to ground their work in
how the code actually works — not generic assumptions. `CLAUDE.md` is the always-on floor;
`agent_docs/` is the load-on-demand depth behind it (progressive disclosure, same principle
as skills). It's **committed**, so it travels into the sandbox — an autonomous run reads the
same context you do.

## Read order
Start here (this index), then open only the docs relevant to the task. Don't read it all.

## What lives here
- `architecture.md` — the system shape: components, boundaries, data flow, where things live.
- `glossary.md` — the domain language (the terms that mean something specific *here*).
- `adr/` — Architecture Decision Records: the durable, **append-only** log of repo-level
  decisions (`adr/README.md` for the convention). Different lifecycle from the docs above —
  those describe current state and get edited/deleted as the code moves; ADRs are history and
  are superseded, never rewritten.
- *(add as the repo needs)* `testing.md`, `data-model.md`, `auth.md`, `deployments.md`, …

## Conventions
- Keep each doc tight and **current** — a stale context doc misleads an agent worse than none.
- One concept per file; link between them.
- A decision that is **hard to reverse + surprising + a real trade-off** belongs in a short
  ADR under `adr/` (`agent_docs/adr/NNNN-slug.md` — Context / Decision / Consequences; see
  `adr/README.md`), not buried in prose. ADRs are durable, repo-level decision memory —
  distinct from a spec's per-task Resolved decisions.

## Who reads it
**Primary (plan phase):** the plan-mode skills (`grill-me`, `write-plan`) and the read-agents
(`scout`, `researcher`) consult these to ground their questions, designs, and exploration in
the real codebase — this is where the codebase model gets baked INTO the spec.

**Fallback (build phase):** a build run leans on its **spec**, not this directory — planning
already resolved the design, so routinely browsing here would undo that. But a builder that
hits a *genuine* codebase question the spec doesn't answer (an unfamiliar module, a domain
term) is allowed and encouraged to pull the one relevant doc rather than guess — e.g.
`diagnose` checking the glossary + ADRs for the area it's debugging. If the gap is a *design*
question (not just unfamiliarity), that's a hard-stop, not a lookup.
