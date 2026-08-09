> ## ⚠ SUPERSEDED — DO NOT EXECUTE
>
> This was the target model before the two decision passes. It is superseded by
> [`specs/harness-standardization/CONTRACT.md`](./CONTRACT.md), with
> [`DECISIONS-PENDING.md`](./DECISIONS-PENDING.md) above it.
>
> **Specifically reversed here:** Depot owning worktree and workspace lifecycle
> (`depot worktree create` / `workspace init` / `orient` / `bind` — none exist and none will);
> `specs/<slug>.scoping.md`; `thoughts.md`; typed history subdirectories and a `history/README.md`;
> the `scoping → … → verified → completed` state list; `~/agents/` as canonical; and spec binding
> with a source-commit pin.
>
> Retained as provenance. *Bannered 2026-08-08.*

# High-Level Context Standard

**Status:** Superseded — provenance only.  
**Date:** 2026-08-07  
**Scope:** Machine-wide harness, Claude/Codex provider adapters, repositories, projects, Git
worktrees, and per-worktree workspace memory.

## Purpose

This document is the high-level context standard for Davis's coding-agent environment. It is the
reference we use to audit and align:

- the machine-level harness and provider entry points;
- every repository and project on the machine;
- the relationship between code, durable documentation, specifications, and agent guidance;
- Git worktrees and the shared context available to agents working in one worktree; and
- Claude, Codex, and future provider adapters.

This is a target architecture, not a claim that every current project already conforms to it. A
follow-up audit will inventory the machine and repositories, identify drift, and converge them on
this model deliberately.

## North star

The code should be clear enough that documentation explains only the non-local knowledge: system
boundaries, domain language, important decisions, project conventions, and task context.

Every piece of context has one canonical owner and one loading policy. We do not maintain parallel
architecture manuals, duplicated provider instructions, or multiple decision logs that can drift.

The layers are:

```text
machine core
  ↓
project/repository harness
  ↓
isolated Git worktree
  ├── committed code and durable project context
  ├── provider adapters
  └── untracked shared task workspace
```

## Terminology

- **Machine:** Davis's local environment across all repositories and providers.
- **Repository/project:** a codebase with its committed source, tests, documentation, and harness.
- **Worktree:** an isolated Git checkout on its own task branch.
- **Workspace:** the task context attached to one worktree. A workspace is not a second checkout
  and is not the repository's durable documentation system.
- **Harness:** the reusable skills, agents, rules, hooks, adapters, and conventions that help an
  agent operate safely and effectively.
- **Provider:** Claude, Codex, or another agent runtime that consumes the same project context
  through a thin native adapter.

## Machine and provider layer

The machine layer stays small and broadly applicable. It holds preferences and universal workflows
that are true across projects. Project-specific facts do not belong here.

Conceptually:

```text
~/agents/                    canonical machine-level source
~/.claude/                   Claude entry point and provider state
~/.codex/                    Codex entry point and provider state
```

The exact symlink and installation mechanics are implementation details of the machine migration,
but the invariant is one canonical machine contract rather than independently edited Claude and
Codex copies.

The machine core may contain universal skills such as brainstorming, diagnosis, TDD, verification,
handoff, and shipping. Larger project skill sets and non-coding or area-specific packs remain at
the project or area layer. Side-effectful workflows such as E2E testing, shipping, Wayfinder,
security review, and teaching are explicitly invoked rather than loaded into every task.

Provider rules:

- `AGENTS.md` is the provider-neutral contract.
- `CLAUDE.md` is a small Claude adapter that imports or points to `AGENTS.md` and adds only
  Claude-specific behavior.
- `.claude/` contains Claude skills, agents, hooks, rules, and settings.
- `.codex/` contains Codex-specific project configuration and adapters.
- Generic workflows remain reusable skills; provider adapters do not fork their content.
- Provider configuration must not become a second home for project architecture or domain truth.

## Canonical project structure

Every adopted repository should converge toward this shape:

```text
project-root/
  AGENTS.md
  CLAUDE.md
  README.md

  docs/
    INDEX.md
    architecture.md
    glossary.md
    adrs/
      README.md
    agent-guidance/
      README.md
      domain.md
      issue-tracker.md
      quality-gates.md
      worktrees.md

  specs/
    README.md
    <slug>.scoping.md       # optional curated problem framing
    <slug>.md
    <epic>/                  # only for decomposed work

  .claude/
  .codex/
```

### Root instruction files

`AGENTS.md` is a short map and always-relevant repository contract. It should contain the
repository identity, stack, structure, real setup and verification commands, hard invariants,
risk hotspots, and pointers to the relevant documentation.

`CLAUDE.md` should not duplicate the project contract. It is the Claude-specific adapter.

Area-specific instructions may live in a nested `AGENTS.md` when a directory has genuinely
different commands or safety rules. Do not create nested instruction files merely to organize
prose.

### `docs/`

`docs/` is the canonical home for durable project knowledge shared by humans and agents:

- `INDEX.md` routes readers to the right document instead of asking them to search everything;
- `architecture.md` describes the current system shape, boundaries, flows, and invariants;
- `glossary.md` owns shared domain language;
- `adrs/` owns append-only repository-level architectural decisions; and
- `agent-guidance/` contains project-specific instructions for reusable skills, such as tracker
  conventions, quality gates, worktree rules, and how to consume the domain documents.

`docs/agent-guidance/` is not a place for generic skill bodies, agent definitions, architecture
duplicates, or a second glossary. It is a project adapter layer.

The project should use one documentation namespace. `agent_docs/`, duplicate `CONTEXT.md` files,
and parallel architecture or decision trees should be retired during convergence rather than
maintained beside `docs/`.

### `specs/`

`specs/` is the top-level, tracked home for formal implementation specifications. A spec is the
shared statement of what should be built and how it will be verified. Worktrees can consume the
same spec in parallel when they contain the commit that introduced it or can fetch it from the
shared spec source.

- `<slug>.scoping.md` is an optional, curated framing of the problem: desired outcome, scope,
  non-goals, constraints, relevant evidence, unresolved questions, and the current approach;
- `<slug>.md` is the canonical build handoff; and
- a T3 epic may use a folder with an index and ordered sub-specs.

Do not create a second committed thought stream by default. Live task memory belongs in the
worktree's `.workspace/thoughts.md` and history. A scoping synthesis reads the mission, thoughts,
relevant history, and repository documents, then writes a concise `specs/<slug>.scoping.md` with
links back to its sources. It summarizes; it does not copy the raw thought stream or large logs.

The build plan consumes the curated scoping document and produces `specs/<slug>.md`. Once the
formal spec is ready, the spec—not the raw thoughts or scoping history—is the builder's contract.
For a T3 epic, the equivalent shape is:

```text
specs/<epic>/
  scoping.md       # optional curated framing
  README.md        # epic contract and ordered sub-specs
  01-*.md
  02-*.md
```

Product-level specifications may live in a separate authoritative product-spec repository. The
repository's `specs/` directory owns implementation handoffs and build sequencing; the two should
link to each other rather than copy one another.

## Worktrees and workspace memory

The isolation rule is:

> One Git worktree equals one workspace.

A typical machine layout is:

```text
~/workspaces/
  <project>/
    <task-worktree>/       Git checkout + task branch
    <another-worktree>/    another isolated checkout + branch
```

The canonical checkout is an anchor for repository maintenance. Active task work happens in a
linked worktree on a non-default branch. Each worktree receives the repository's committed
harness, docs, and specs through Git, while its workspace memory is local to that worktree.

### The `.workspace/` contract

`.workspace/` is untracked, ignored, provider-neutral task memory shared by all Claude, Codex, and
future sessions attached to the same worktree:

```text
.workspace/
  MISSION.md
  thoughts.md
  history/
    README.md
    handoffs/
    research/
    verification/
    findings/
  artifacts/
```

The initial contract is intentionally small. Optional directories are created when the task needs
them; a fresh worktree does not need an empty copy of every directory.

#### Creation and lifecycle

Depot owns the operational worktree and workspace lifecycle through a CLI that can be run from any
terminal, IDE terminal, Claude or Codex session, script, or Depot UI. The UI is a client of the same
operations; it is not required for them.

```text
depot worktree create <project> --branch <branch> [--base <ref>] [--objective <text>] [--spec <path>]
  → create the Git worktree
  → initialize `.workspace/`
  → write the initial `MISSION.md`
  → optionally bind a formal spec
  → run the project-owned setup
```

`depot workspace init` performs the workspace portion for an existing worktree. It is idempotent,
creates no duplicate memory, and never overwrites an existing mission or history. It may be run
from the worktree or with an explicit path.

`depot workspace orient` is read-only. It returns the repository, worktree, branch, workspace
identity, mission state, linked scoping/spec documents, current position, next action, blockers,
and selected recent records. It does not guess a spec, load all history, rewrite `MISSION.md`,
synthesize scoping, or repair malformed files.

`depot workspace bind --spec specs/<slug>.md` explicitly attaches a formal implementation spec to
the workspace. The binding records the repository-relative path and source commit in `MISSION.md`;
it never copies the spec into `.workspace/`. A workspace may begin unbound while it is being scoped.

`MISSION.md` is the compact control card. It should identify the repository, branch/workspace, and
linked spec, then state the objective, scope, constraints, current position, next action, blockers,
open questions, and—when needed—active task ownership.

It is not empty at creation. A new workspace receives a small scaffold with generated identity and
an explicit `state: scoping` and `spec: null` when no objective or spec was supplied. Its initial
objective is not guessed. The first agent sessions accumulate the real objective, scope,
constraints, and next action in `MISSION.md`, while raw reasoning accumulates in `thoughts.md` and
history records.

The normal lifecycle is:

```text
create/init
  → scoping
  → specs/<slug>.scoping.md
  → specs/<slug>.md
  → explicit workspace bind
  → building
  → verified
  → completed or abandoned
```

`thoughts.md` is the live reasoning buffer: ideas, open questions, assumptions, discoveries, and
working decisions. It is intentionally raw and mutable. It is not duplicated as a committed
`specs/<slug>.thoughts.md` file, and it is not the permanent architecture or decision log. A
scoping synthesis may curate its useful conclusions into `specs/<slug>.scoping.md`; durable
conclusions are promoted separately to the spec, `docs/`, an ADR, or an issue.

`history/` is broad but semi-structured append-only evidence and continuity. Its initial record
types are:

- **handoffs:** what the next session or agent needs to resume;
- **research:** questions, evidence, sources, limitations, and conclusions;
- **verification:** test, E2E, evaluation, quality-gate, and regression-run summaries; and
- **findings:** bugs, gaps, inconsistencies, or follow-up work discovered during implementation or
  verification.

Findings carry a status such as `open`, `resolved`, `promoted`, or `wont-fix`; a `to-review/`
directory is not required. Raw screenshots, traces, recordings, generated reports, and large logs
belong in `artifacts/`, with a readable history record linking to them.

The workspace is not a second shared repository. Different worktrees have different `.workspace/`
directories. Cross-worktree coordination happens through the tracked spec, the issue tracker, PRs,
or promoted project documentation.

The ownership boundary is intentional:

- **Depot** owns worktree creation, workspace initialization, identity, lifecycle, and CLI/service
  operations;
- **the harness** owns the portable `.workspace/` file contract and agent workflows;
- **the project** owns setup commands, dependencies, environment preparation, and repository
  guidance; and
- **the UI** is an optional client of Depot, not the only execution surface.

### Ownership and promotion

```text
.workspace/thoughts.md + history
              ↓  scope
specs/<slug>.scoping.md      curated problem framing
              ↓  write-plan
specs/<slug>.md              current implementation contract
              ↓  explicit promotion
docs/ or docs/adrs/          durable repository knowledge and decisions
```

History preserves provenance; it does not become the current source of truth by accident. A
handoff may be consumed, a finding may be resolved, and a research result may be promoted, but the
original record remains an auditable part of the worktree history until the worktree is archived or
removed.

### Promotion gates

Promotion is a deliberate decision, not an automatic consequence of an agent noticing something.
The scoping synthesis may propose promotion candidates, but it must not silently edit `docs/` or
`docs/adrs/`.

Promote to the tracked implementation spec when the material changes what the current task should
build, its acceptance criteria, its constraints, or its execution plan.

Promote to `docs/architecture.md` only when the material describes current repository truth that
will help future work understand the system, or when an accepted code change makes the existing
architecture documentation false. Do not put proposals, one-off implementation notes, raw test
results, or unresolved findings there.

Promote to `docs/glossary.md` only when a term is used across capabilities or tasks, is ambiguous
enough to cause mistakes, or represents a stable domain concept. Local variable names and
task-specific vocabulary stay local.

Create an ADR only when all of the following are true:

1. the decision has durable architectural, data-model, dependency, security, or operational
   consequences;
2. a future maintainer would reasonably need to know why this choice was made;
3. meaningful alternatives or trade-offs existed; and
4. the decision is accepted, not merely proposed or still being explored.

One-off implementation choices, rejected ideas, temporary debugging conclusions, test failures,
and follow-up work do not become ADRs by default. They remain in scoping, the spec, or
`history/findings/`; findings that outlive the worktree should become an issue, spec change, or
explicitly approved documentation update.

Machine-local secrets, provider runtime state, dependency caches, databases, tmux state, and
operational workspace registries do not belong in `.workspace/`. Environment setup is a
project-specific bootstrap concern and must never put secret values into committed context.

## Source-of-truth rules

| Question | Canonical home |
| --- | --- |
| What does this repository do? | `README.md` + `docs/architecture.md` |
| What does a domain term mean? | `docs/glossary.md` |
| Why was an architectural choice made? | `docs/adrs/` |
| What is the curated framing for this task? | `specs/<slug>.scoping.md` |
| What should this task build? | `specs/<slug>.md` |
| What is this worktree currently doing? | `.workspace/MISSION.md` |
| What is the agent thinking through right now? | `.workspace/thoughts.md` |
| What happened during the work? | `.workspace/history/` |
| What raw evidence was produced? | `.workspace/artifacts/` |
| How should a generic skill operate in this repo? | `docs/agent-guidance/` |
| What is provider-specific? | `.claude/`, `.codex/`, and native provider config |

When a claim could fit in two places, choose the owner by lifetime: current repository truth belongs
in `docs/`, task intent belongs in `specs/`, live work belongs in `.workspace/`, and provider
behavior belongs in the provider adapter.

## Convergence audit

The follow-up audit should inspect the machine and every canonical project/repository for:

1. one canonical machine contract with thin Claude and Codex entry points;
2. a short root `AGENTS.md` and non-duplicating `CLAUDE.md` adapter;
3. a single `docs/` namespace with an index, current architecture, glossary, ADRs, and only the
   agent guidance the project actually needs;
4. a tracked top-level `specs/` convention with optional curated `scoping.md` and no duplicate
   committed thought stream;
5. no parallel `agent_docs/`, architecture, glossary, or decision sources;
6. `.claude/` and `.codex/` containing provider configuration rather than copied project truth;
7. worktrees on task branches with reproducible setup and safe environment handling;
8. `.workspace/` local to each worktree, ignored, and shaped around `MISSION.md`, `thoughts.md`,
   typed history, and artifacts; and
9. a visible promotion gate preventing routine task context from filling `docs/` or `docs/adrs/`;
10. project-specific skills, agents, plugins, and quality gates placed at the smallest layer that
   needs them rather than promoted into the universal core.

This document defines the target. The audit, migration, verification, and cleanup are separate
work and must report exceptions instead of silently inventing local variants.
