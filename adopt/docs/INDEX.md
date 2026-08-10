# docs/ — durable repository truth

The docs an agent reads to understand **this** codebase: how it's built, the domain language,
the decisions behind it. `AGENTS.md` is the always-on profile; `docs/` is the load-on-demand
depth behind it — the same progressive-disclosure principle as skills. It's **committed**, so it
travels into a sandbox clone: an autonomous run reads the same context you do.

`docs/` holds durable repository truth only. **Planning and research artifacts do not live here**
— they live under `specs/<epic>/` with the work they inform, and age out with it.

## Read order
Start here, then open only what the task needs. Don't read it all.

| File | Holds |
| --- | --- |
| `architecture.md` | the system shape: components, boundaries, data flow, key invariants |
| `glossary.md` | the domain language — terms that mean something specific *here* |
| `adrs/` | Architecture Decision Records: durable, **append-only** decision memory |
| `agent-guidance/` | *(optional)* project adapters for generic skills |

Add more as the repo needs (`testing.md`, `data-model.md`, `auth.md`, `deployments.md`, …).
Keep `docs/` flat apart from those two subdirectories.

## Conventions
- Keep each doc tight and **current** — a stale context doc misleads an agent worse than none.
- One concept per file; link between them, never paste.
- `architecture.md` and `glossary.md` describe *current state*: edit and delete them freely as
  the code moves. `adrs/` is history — superseded, never rewritten.
- A decision that is **hard to reverse + surprising + a real trade-off** earns an ADR. Anything
  else stays in its spec.

## Promotion — always ask, never write silently
An agent that notices something worth promoting here — an ADR, a glossary entry, an architecture
correction — **says so and asks**. It never creates one on its own. Promotion happens at merge,
and **ships as a separate PR**, so documentation never blocks code.

Because a worktree's `.workspace/LOG.md` may be gone by merge time, **the PR body carries the
settled decisions**. It is the only bridge, and nothing checks that it happened.
