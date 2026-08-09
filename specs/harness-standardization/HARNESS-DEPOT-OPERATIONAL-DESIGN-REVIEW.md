# Harness + Depot Operational Design Review

**Status:** **Provenance.** No longer authoritative. All fifteen decisions were resolved here on
2026-08-07/08; a second decision pass on 2026-08-08 (A–J) amended several of them.  
**Scope:** Machine harness, Claude/Codex adapters, projects, Git worktrees, `.workspace/`, specs, Depot, verification, promotion, and cleanup.

> ## ⚠ AUTHORITY — read this first
>
> **This document is no longer the source of truth.** Authority order:
>
> 1. `specs/harness-standardization/DECISIONS-PENDING.md` — the decisions and the verified facts
> 2. `specs/harness-standardization/CONTRACT.md` — the operating model
> 3. **this document** — DEC-1…15 evidence and provenance
> 4. `specs/harness-standardization/plan/tasks.md` — the execution plan
>
> Where any two disagree, the higher entry wins. Nothing in this document should be executed.
>
> **Within this document:** everything from "Current machine state" through "Recommended revised
> workflow" is original pre-decision analysis. **Resolved decisions** below records DEC-1…15 as
> settled in pass 1 — several clauses of which pass 2 superseded. Those are marked inline. Per
> DEC-13 this document moves to `specs/harness-standardization/` during migration.
>
> ### Pass-2 amendments to DEC-1…15
>
> | DEC | What changed |
> | --- | --- |
> | DEC-2 | Five worktree-creation paths, not three — Claude's and Codex's built-in features were both missing, and they account for most of the 101 live worktrees. Init is now **eager** via Claude's `WorktreeCreate` hook, with SessionStart as the net. The **spec-binding** row is void (DEC-6) and the **export-before-removal** clause is void (DEC-8). |
> | DEC-3 | The "scoping synthesis producing `specs/<slug>.scoping.md`" sentences are void (DEC-5). |
> | DEC-4 | `spec` is a **plain path**, never `{path, commit}` (DEC-6). **Drift reporting is void** (DEC-6). The two obligations now have **named owners** and "at session end" is dropped. |
> | DEC-7 | "Records cannot collide" is true **only given atomic `O_EXCL` creation**, which pass 2 added. |
> | DEC-11 | E2E is removed from the harness entirely. `hot-mac` is a tenth unversioned skill with no layer assigned. |
> | DEC-12 | The **LSP claim is struck** — no LSP plugin is installed. Plugin scoping is **untested**, not an accepted exception. Hook parity is **not** achieved by registration alone: Codex sends edits via `apply_patch`. |
> | DEC-14 | **Superseded.** No review runs automatically at all — not `reviewer`, not `reviewer-security`, not at `/ship`. |
> | DEC-15 | The default journey is **three steps** (`wt` → build → ship); the twelve-step sequence is the T3 maximal case. |
>
> ### Factual corrections to this document
>
> - `~/.config/depot/projects.yaml` **exists** and registers four projects. It is promoted to
>   `~/.config/agents/projects.yaml` rather than replaced.
> - **Ten** skills are unversioned, not nine — `hot-mac` was missed.
> - `~/.agents/skills` has **already drifted** from the repo.
> - There are **101** secondary worktrees across the four repos.
> - **Cleanup is not manual-only.** Both providers remove worktrees automatically.

## Purpose

This document preserves the design review of the proposed coding-agent harness before implementation begins.

The goal is not merely to standardize files. The goal is to make the end-to-end operating model unambiguous:

```text
machine harness
  -> project adapter
  -> Git worktree
  -> local workspace memory
  -> curated scoping
  -> tracked implementation spec
  -> build and verification
  -> explicit promotion
  -> pull request and cleanup
```

The harness and Depot are not operationally aligned until the ownership and lifecycle decisions recorded below are resolved. This document is therefore a decision gate and a durable reference for the next implementation conversation.

## Executive conclusion

The model is conceptually coherent:

- repository code and durable documentation are repository truth;
- a tracked top-level spec is the build contract;
- `.workspace/` is local, ignored, per-worktree working memory;
- Claude and Codex share the same provider-neutral semantic contract;
- raw thinking, research, handoffs, findings, and evidence are kept out of durable docs by default;
- promotion into specs, architecture docs, glossary entries, and ADRs is explicit.

The current documents do not yet describe one implementable system. The largest conflict is the Depot boundary:

- the harness standard says Depot owns worktree and semantic workspace lifecycle;
- Depot's active `control-plane-v1` specification says Depot must remain harness-agnostic and must not initialize or mutate `.workspace/`;
- the current Depot CLI does not expose the proposed worktree/workspace commands.

Implementation should pause at this boundary. Otherwise we will create competing workspace owners and multiple incompatible context models.

> **Resolved 2026-08-07 by DEC-1:** Depot stays an operational cockpit. The Depot side was already
> shipped and correct; the harness documents were the ones asserting an unbuilt boundary. See
> **Resolved decisions** below — all fifteen are settled and this document is now the implementation
> handoff.

## Current machine state versus target machine state

### Current state observed

The current machine topology is:

```text
~/.claude  -> /Users/daviscohen/agents/claude   (symlink)
~/.codex   -> /Users/daviscohen/.codex         (separate real directory)
~/agents/claude                               (Claude machine tree)
~/agents/codex                                (currently empty)
~/.agents                                     (separate real directory)
```

This is an observation of the current machine, not the intended contract. In particular:

- Claude's global tree and Codex's global tree are not currently one canonical provider-neutral source;
- `~/.codex/AGENTS.md` is empty;
- Claude and Codex currently expose different skill inventories;
- Claude has a global SessionStart hook and project-level hooks, while Codex's project hook/configuration surface is not yet equivalent;
- the frontend-design plugin is enabled globally, but optional area-pack boundaries are not formally defined;
- the current security reviewer is configured as Sonnet, while the desired security-review policy may require Opus.

Relevant live files:

- `/Users/daviscohen/agents/claude/settings.json`
- `/Users/daviscohen/.codex/config.toml`
- `/Users/daviscohen/.codex/AGENTS.md`
- `/Users/daviscohen/agents/claude/agents/reviewer-security.md`

### Target state

The target is one canonical machine contract under `~/agents`, with thin provider entry points:

```text
~/agents/
  canonical machine-level contract
  universal skills
  universal agents
  universal safety hooks
  shared rules
  optional area packs

~/.claude/
  Claude provider entry point and runtime state

~/.codex/
  Codex provider entry point and runtime state
```

The exact machine manifest is still a decision. The likely universal core is:

- brainstorm/design exploration;
- diagnosis;
- TDD when non-trivial logic is being added;
- verification before completion;
- handoff/continuity;
- review and shipping procedures;
- narrow scout/research/reviewer/security-review agents;
- default-branch, dangerous-command, and secret-protection hooks.

The following should normally be explicit or optional rather than always-on:

- Wayfinder, because it writes to an issue tracker;
- teach, because it creates a separate teaching workspace;
- E2E testing, because it can be expensive and environment-dependent;
- frontend-design and browser tooling, because they are area packs;
- specialized MCPs and plugins;
- security review, which should be universally available but invoked for risk hotspots and governed by an explicit model policy.

## Canonical repository and workspace model

The target project shape is:

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
    <slug>.scoping.md
    <slug>.md
    <epic>/
  .claude/
  .codex/
```

The target `.workspace/` contract is:

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

`.workspace/` is:

- local to one Git worktree;
- ignored and untracked;
- shared by all Claude/Codex sessions attached to that worktree;
- not a second repository;
- not a home for secrets or durable repository truth.

The current Melting v2 documents still describe a different shape:

```text
.workspace/
  workspace.md
  scoping/
  spec/
  history/
  artifacts/
```

The current harness still describes committed `specs/<slug>.thoughts.md`, `.context/`, `.sessions/`, and `agent_docs/`. These are not compatible details; one model must be selected and the others retired or explicitly scoped as legacy.

## Realistic user journey under the target model

### 1. Choose a project and create a worktree

User action:

```bash
depot worktree create melting-v2 \
  --branch feature/inbox \
  --base origin/main \
  --objective "Add inbox filtering"
```

Or, when a formal spec already exists:

```bash
depot worktree create melting-v2 \
  --branch feature/inbox \
  --spec specs/inbox-filtering.md
```

Intended behavior:

1. create the Git worktree and task branch;
2. initialize `.workspace/`;
3. write `MISSION.md`;
4. optionally bind the formal spec;
5. run project-owned setup.

The Depot UI should be optional. The same operation should work from iTerm, an IDE terminal, a Claude session, a Codex session, or a script.

Files read:

- Depot's project registry/configuration;
- Git refs and repository metadata;
- project setup configuration.

Files written:

- Git worktree metadata and branch;
- the checked-out repository;
- ignored `.workspace/` files;
- project-local environment/dependency state as defined by setup.

Tracking:

- branch and repository files are Git-managed;
- `.workspace/` is ignored/untracked;
- environment state is project-specific and must not contain committed secrets.

Action type: intended to be explicit user action with automatic initialization/setup.

Current reality: the proposed `depot worktree create` command is not in the current Depot CLI. Current worktree creation is Git-only; it does not initialize `.workspace` or run project setup.

### 2. Start without a mission or spec

If neither an objective nor a spec is supplied, the new workspace must not invent one.

It should receive an explicit initial state:

```yaml
state: scoping
spec: null
```

The exact `MISSION.md` schema remains unspecified. The intended shape is approximately:

```markdown
---
workspace_id: <generated-id>
project: melting-v2
worktree: feature-inbox
branch: feature/inbox
state: scoping
spec: null
---

# Mission

## Objective

Not yet stated.

## Scope

Not yet stated.

## Constraints

None recorded.

## Current position

Workspace initialized; the task has not been scoped.

## Next action

Clarify the objective and scope.

## Blockers

None known.
```

This is an illustrative contract, not an existing implementation. The exact frontmatter, identity fields, update rules, and state transitions still need to be specified.

### 3. Open Claude or Codex and orient

User action:

```bash
cd ~/workspaces/melting-v2/feature-inbox
claude
```

or:

```bash
cd ~/workspaces/melting-v2/feature-inbox
codex
```

User prompt:

```text
Orient me in this worktree and help me scope the feature. Start with brainstorm.
```

The intended read-only orientation command is:

```bash
depot workspace orient
```

It should report:

- repository, worktree, and branch;
- workspace identity;
- mission state;
- linked scoping/spec documents;
- current position and next action;
- blockers;
- selected recent records.

It must not guess a spec, rewrite `MISSION.md`, synthesize scoping, repair malformed files, or load all history.

Files read:

- root `AGENTS.md`;
- provider adapter (`CLAUDE.md` or `.codex/`);
- project rules and skills;
- `docs/INDEX.md` and relevant project docs;
- `.workspace/MISSION.md`;
- selected recent history.

Files written: none.  
Action type: provider loading is automatic; orientation is explicit and read-only unless a future provider hook only displays its result.

Current reality: `depot workspace orient` is not implemented.

### 4. Scope the work

The intended planning sequence is:

```text
brainstorm
  -> grill-with-docs / grill-me
  -> targeted scout/research
  -> scoping synthesis
  -> write-plan
```

Typical prompts:

```text
Help me explore the problem and give me two or three approaches.
```

```text
Grill me on the design, one decision at a time.
```

```text
Research the unknown API behavior and record the evidence.
```

Raw planning state belongs in:

```text
.workspace/thoughts.md
.workspace/history/research/<record>.md
.workspace/history/findings/<record>.md
.workspace/artifacts/<raw-evidence>
```

These files are ignored/untracked.

The skill boundaries are important:

- `brainstorm` is conversational divergence and approach selection;
- `grill-me` resolves design decisions one at a time;
- `grill-with-docs` grounds the discussion in repository docs and terminology;
- `scout` maps the codebase read-only;
- `researcher` gathers external evidence read-only;
- `wayfinder` is an explicit issue-tracker planning workflow for work too large for one session;
- `teach` is an explicit teaching workspace, not ordinary coding-task memory.

Current skill files still point at `agent_docs/`, `specs/<slug>.thoughts.md`, or a root-level `MISSION.md` in the case of teaching. They need adaptation before they can be the target workflow.

### 5. Synthesize scoping

The scoping synthesizer reads:

- `.workspace/MISSION.md`;
- `.workspace/thoughts.md`;
- relevant history records;
- relevant repository documentation;
- targeted code/research findings.

It writes:

```text
specs/<slug>.scoping.md
```

This file is tracked, reviewed, and committed. It should contain concise problem framing, scope, constraints, discoveries, open decisions, and links to evidence. It must not copy raw thoughts, logs, or screenshots.

The synthesis is explicit. It is not a side effect of orientation.

### 6. Produce the formal implementation spec

User action:

```text
Turn the accepted scoping document into a build-ready spec.
```

The `write-plan` skill reads:

- `specs/<slug>.scoping.md`;
- repository instructions;
- architecture, glossary, and accepted ADRs;
- relevant research records;
- the codebase where needed.

It writes:

```text
specs/<slug>.md
```

The formal spec is tracked and becomes the builder's contract. It contains the resolved requirements, design, acceptance criteria, constraints, risks, verification method, and ordered tasks.

The builder should not read `.workspace/thoughts.md` by default. Raw thinking is a planning input, not the implementation contract.

### 7. Bind the formal spec

After the spec is committed or otherwise available in the worktree:

```bash
depot workspace bind --spec specs/inbox-filtering.md
```

Intended behavior:

- record the repository-relative path in `MISSION.md`;
- record the source commit;
- do not copy the spec into `.workspace/`.

The workspace may remain unbound during scoping.

Each worktree binds the spec independently. Multiple worktrees can point to the same spec path and source commit, but an uncommitted spec in Worktree A is not visible to Worktree B. The spec must be committed, pushed, or otherwise made available before parallel worktrees can use it reliably.

The design still needs an explicit stale-binding policy. Recommended behavior:

- orientation reports spec drift when the file no longer matches the recorded source commit;
- the builder does not silently use the changed spec;
- rebinding is explicit.

### 8. Build against the spec

The builder reads:

- `AGENTS.md`;
- `CLAUDE.md` or `.codex/`;
- relevant provider rules;
- relevant project docs;
- `.workspace/MISSION.md`;
- the bound `specs/<slug>.md`.

It does not automatically read the entire workspace history, every artifact, raw thoughts, or unrelated documents.

Lifecycle skills and agents:

| Activity | Skill/agent | Invocation |
| --- | --- | --- |
| New non-trivial logic | `tdd` | explicit or trigger-based |
| Hard bug/performance issue | `diagnose` | explicit or trigger-based |
| Codebase exploration | `scout` | explicit planning subagent |
| External research | `researcher` | explicit planning subagent |
| General review | `reviewer` | explicit before handoff/PR |
| Security review | `reviewer-security` | explicit for risk hotspots |
| E2E testing | `e2e-test` | explicit when required |
| Simplification | `simplify` | explicit review pass |
| Final verification | `verify-before-done` | explicit before completion claim |
| Shipping | `open-a-pr` or `ship` | explicit user request |

Code and tests written during building are tracked changes. Workspace checkpoints, observations, raw logs, and findings remain ignored/untracked unless explicitly promoted.

### 9. Use multiple sessions or worktrees

Multiple Claude/Codex sessions in one worktree share:

- the checkout;
- branch;
- `.workspace/`;
- `MISSION.md`, thoughts, history, and artifacts;
- tracked specs and project docs.

They do not share conversation context or provider runtime state. Concurrent writes to `MISSION.md` and `thoughts.md` are possible; locking and append rules are not yet specified.

Separate worktrees isolate:

- code and uncommitted changes;
- branch;
- `.workspace/`;
- local findings and handoffs.

They can share committed specs, docs, issues, and pull requests. Cross-worktree coordination must happen through those shared surfaces, not through `.workspace/`.

### 10. Handoff, verify, and ship

The target handoff location is:

```text
.workspace/history/handoffs/<timestamp>-<summary>.md
```

Verification records belong in:

```text
.workspace/history/verification/<timestamp>-<summary>.md
```

Research and findings use their corresponding typed directories. Large evidence belongs in `artifacts/` and is linked from the readable record.

The next agent should be able to resume with:

```text
Orient me in this worktree. Read the current mission, bound spec, latest handoff, and open findings.
```

Before shipping:

1. run the ordinary project test suite;
2. run targeted verification for the acceptance criteria;
3. run security review for relevant hotspots;
4. run E2E explicitly when required;
5. run the reviewer;
6. run `verify-before-done`;
7. use one explicit shipping skill.

The shipping action may commit, push, and open a pull request, so it must never be automatic.

### 11. Findings and cleanup

Findings should remain in workspace history with a status such as:

```text
open
resolved
promoted
wont-fix
```

If a finding needs work later, it should be promoted to an issue, a new/changed spec, or an explicitly approved durable documentation change. The original finding remains as provenance.

Before removing a worktree, important handoffs and findings must be promoted or exported. Otherwise ignored `.workspace/` contents disappear with the worktree.

This preservation operation is not currently defined. Depot V1 explicitly defers archive/snapshot behavior, so cleanup is presently a design gap.

## Source-of-truth boundaries

| Question | Canonical home |
| --- | --- |
| What does the repository currently do? | `README.md` + `docs/architecture.md` |
| What does a stable domain term mean? | `docs/glossary.md` |
| Why was a durable architectural decision made? | `docs/adrs/` |
| What is the curated framing for this task? | `specs/<slug>.scoping.md` |
| What should this task build? | `specs/<slug>.md` |
| What is this worktree currently doing? | `.workspace/MISSION.md` |
| What is being thought through now? | `.workspace/thoughts.md` |
| What happened during this worktree? | `.workspace/history/` |
| What raw evidence was produced? | `.workspace/artifacts/` |
| How should a generic skill operate in this project? | `docs/agent-guidance/` |
| What is provider-specific? | `.claude/`, `.codex/`, and native provider config |

Promotion rules:

- stay in `.workspace/` when information is temporary, task-local, raw, unresolved, or only useful to the current worktree;
- promote to the scoping document when it clarifies the task framing;
- promote to the formal spec when it changes what the current task builds, its acceptance criteria, constraints, or plan;
- promote to architecture docs only when it describes current repository truth;
- promote to the glossary only when the term is stable, reusable, and likely to prevent mistakes;
- create an ADR only for an accepted, durable decision with meaningful alternatives and future-maintainer value.

`grill-with-docs` should propose ADR/glossary candidates rather than silently create them during exploration.

## Resolved decisions

Decisions settled in the 2026-08-07 design-review session. Each is binding on the target workflow;
downstream document corrections are listed but not yet applied.

### DEC-1 — Depot boundary: operational cockpit only

**Decision.** Depot remains a harness-agnostic operational cockpit. It never creates, writes,
validates, repairs, interprets, or requires `.workspace/`. Agents own `.workspace/` — they write it
and read it. `.workspace/` is an invariant that comes with a worktree, but the worktree-creation
command the user actually runs is harness-owned, not Depot, and it must create `.workspace/` as part
of creating the worktree.

Depot ADR 0004 and `specs/control-plane-v1/README.md` stand unamended. Depot may render
`.workspace/` read-only, which control-plane V1 already permits.

**Evidence confirming the shipped Depot boundary:**

- `depot/agent_docs/adr/0004-harness-agnostic-operational-control-plane.md` — status `accepted`,
  supersedes 0001 and 0003.
- `depot/specs/control-plane-v1/README.md` — `.workspace/` initialization/mutation and automatic
  project setup are explicitly out of scope.
- Depot commits `5d2f421`, `c932a66`; `src/depot/workspace/` source modules are deleted.
- `src/depot/worktrees.py:107` — "Create a Git worktree only; no setup, harness, or workspace files
  are touched."
- `src/depot/cli.py` exposes only `doctor`, `install`, and `project add`. Worktree creation exists
  only as `POST /api/worktrees`.

**Downstream effects (not yet applied):**

- `HIGH-LEVEL-CONTEXT.md` lines ~226–305 must stop asserting that Depot owns worktree and
  workspace lifecycle, and must drop `depot worktree create`, `depot workspace init`,
  `depot workspace orient`, and `depot workspace bind` as the named commands.
- `specs/harness-standardization/plan/tasks.md` lines ~204–216 must have those four commands
  replaced by the harness-owned equivalent; this also removes the existing internal contradiction
  with line ~299, which already requires Depot's operational boundary to stay separate.
- `melting-v2/docs/workspace.md` — "Depot creates, validates, archives, and repairs `.workspace/`"
  and "Depot's `workspace` CLI ... remain the intended path" are now false and must be rewritten.
- `melting-v2/docs/agent-environment.md` — "Depot initializes this tree inside each managed
  worktree" and "Depot owns the workspace-memory lifecycle" are now false.
- This document's §"Realistic user journey" steps 1, 3, and 7 must be rewritten off the `depot`
  command names.
- Contradictions 1, 5, and 6 below are resolved by this decision.

**Promotion candidates (not promoted):** none yet. A harness-side ADR recording this boundary is a
candidate once the harness repository's own `docs/adrs/` exists.

### DEC-2 — Operation ownership

**Decision.** Ownership is split as follows:

| Operation | Owner |
| --- | --- |
| Git worktree creation | Depot (API/UI/phone), the harness `wt` command, or plain `git` — all are valid entry points |
| `.workspace/` initialization | Harness, idempotent; run by the harness creation command **and** by a SessionStart hook on both providers |
| Project setup | Project, via the already-live `make setup` / `SETUP_STEPS` overlay; invoked by the harness command, never by Depot |
| Orientation | Harness skill; read-only; reads `MISSION.md` |
| Spec binding | Harness command writing `MISSION.md` |
| Worktree removal | Depot's existing guarded trash, preceded by an explicit harness export step |

`.workspace/` appears on **any worktree an agent opens**, regardless of how the worktree was
created. This is enforced by a lazy idempotent SessionStart initializer, making `.workspace/` an
invariant of "a worktree an agent works in" rather than a convention of one command.

The initializer must be a **separate hook script** (e.g. `ensure-workspace.sh`), not an addition to
`inject-global-rules.sh`. That script's core logic exits early whenever an ancestor directory
contains `.claude/` or `CLAUDE.md` — i.e. in every adopted repository — so workspace init bolted
into it would be skipped exactly where it is needed. Two hooks, one job each.

Phone-created worktrees are covered by the same mechanism without any Depot change: Depot's daemon,
git worktree creation, and tmux session launch all execute on the machine at the project's
`worktree_root`, so a phone-attached agent session fires the machine's SessionStart hook in that
worktree.

**Additive, non-blocking Depot enhancement:** a per-project opaque `post_create_cmd` that Depot
invokes after worktree creation and never interprets, so a phone-created worktree gets `.workspace/`
at creation time rather than at first session. This is architecturally consistent with Depot's
existing opaque `dev_cmd` and launcher commands, and control-plane V1 lists project setup as
deferred rather than forbidden. It requires its own small Depot spec and **must not block** the
harness migration.

**Downstream effects (not yet applied):**

- The harness needs a new machine-level worktree-creation command installed from `~/agents`,
  and a `ensure-workspace.sh` SessionStart hook registered in both `~/agents/claude/settings.json`
  and `~/.codex/hooks.json`.
- `make work SPEC=` and the `.claude/active-spec` pointer become a second binding store competing
  with `MISSION.md`. `melting-v2/docs/workspace.md` already records that the hook consuming that
  pointer was removed, leaving it inert. Retirement is deferred to Decision 6.
- Contradiction 6 (setup ownership) is resolved: the project owns setup via `make setup`; Depot
  never invokes it.
- A new Depot spec is required for `post_create_cmd`; it is out of scope for control-plane V1.

**Promotion candidates (not promoted):** a Depot ADR or sub-spec for `post_create_cmd`, deferred
until the harness command exists.

### DEC-3 — Canonical `.workspace/` schema

**Decision.** The canonical schema is deliberately minimal, optimized for a coding agent to
understand and use correctly inside a worktree without consulting a separate contract:

```text
.workspace/
  MISSION.md                      where we are now; overwritten
  LOG.md                          ordered DECISION / QUESTION entries; appended
  history/
    <utc>-<type>-<slug>.md        type ∈ {handoff, finding}
  artifacts/
```

The three writable surfaces are separated by **mutability and lifetime**, which is the model an
agent applies:

| Surface | Mutability | Holds |
| --- | --- | --- |
| `MISSION.md` | overwritten | the current position |
| `LOG.md` | append-ordered | settled decisions and still-open questions |
| `history/` | append-only, immutable | the two things another session must find |

Rules:

- `.workspace/` does **not** own a `spec/` or `scoping/` subtree. Scoping and formal specs are
  tracked files under `specs/` from the first write. There is exactly one spec lifecycle and one
  home for it.
- `history/` is **flat**. There are no typed subdirectories. The record type is encoded in the
  filename, so an agent needs one naming rule rather than a directory taxonomy.
- Directories are created on demand; a fresh worktree does not receive an empty copy of everything.
- `artifacts/` holds large raw evidence (screenshots, traces, logs, generated reports), linked from
  a readable `history/` record.
- No `history/README.md`. The naming convention is documented in the harness contract, not in an
  untracked directory.

**Evidence this is a greenfield choice, not a migration.** There are zero `.workspace/` directories
anywhere under `~/melting`, `~/dev`, or `~/smoke`. In the harness `.claude/` tree there are zero
references to `.workspace` and zero to `MISSION.md`, against 11 files referencing `agent_docs`,
7 referencing `thoughts.md`, 3 referencing `.sessions/`, and 2 referencing `.context/`. Both
candidate schemas were paper; the only one ever implemented (Depot's) has been deleted. There is no
migration cost and no incumbent to protect.

**Record types.** Exactly two: `handoff` and `finding`. Research results and verification runs are
recorded as `finding` records. Decisions are **not** history records — they accumulate as ordered
entries in `LOG.md`, because a grilling or brainstorm session produces many decisions in sequence
and one ordered file is materially easier to append to and read back than N timestamped files. The
vocabulary can be extended later; it starts as small as it can usefully be.

**Why `LOG.md` and not a scratch pad.** The accumulated output of `brainstorm` + `grill-*` is not
disposable scratch; it is an ordered ledger of settled decisions with their evidence, rejected
alternatives, and consequences, plus the threads still open. That ledger is the direct input to the
scoping synthesis that produces `specs/<slug>.scoping.md`. The existing harness already had the
right *shape* for this — `specs/<slug>.thoughts.md` carries typed `DECISION` / `QUESTION` entries
(`.claude/skills/grill-me/SKILL.md:42-45`), a Brainstorm thread section
(`.claude/skills/brainstorm/SKILL.md:41,57`), and is greppable enough that
`.claude/skills/overview-fresh/SKILL.md:27` extracts `DECISION [0-9]+` from it. What was wrong was
its **location** — committed and per-spec — not its structure. `LOG.md` keeps the shape and moves it
to one untracked file per worktree.

**Downstream effects (not yet applied):**

- **Every skill and agent-facing document mentioning `thoughts.md` must reference `.workspace/LOG.md`
  instead.** This is a *relocation*, not a basename find/replace: today the name always means the
  committed, per-spec `specs/<slug>.thoughts.md`; it becomes one untracked, per-worktree file.
  Fourteen files reference it:

  | File | Nature of the change |
  | --- | --- |
  | `.claude/skills/brainstorm/SKILL.md` | writes the Brainstorm thread + `DECISION` entries → `.workspace/LOG.md` |
  | `.claude/skills/grill-me/SKILL.md` | writes `DECISION` / `QUESTION` entries → `.workspace/LOG.md` |
  | `.claude/skills/write-plan/SKILL.md` | reads the thread → reads `.workspace/LOG.md` and `specs/<slug>.scoping.md` |
  | `.claude/skills/handoff/SKILL.md` | "link, don't duplicate" target → `.workspace/LOG.md` |
  | `.claude/skills/overview-fresh/SKILL.md` | **premise breaks** — see below |
  | `.claude/skills/VENDORED.md` | vendoring provenance note |
  | `.claude/rules/specs.md` | retires the `<slug>.thoughts.md` convention |
  | `specs/templates/t2/spec.thoughts.md` | delete |
  | `specs/templates/t2/spec.context.md` | reconcile with the retirement of `.context/` |
  | `specs/README.md`, `specs/harness-standardization/plan/tasks.md` | convention references |
  | `HIGH-LEVEL-CONTEXT.md`, `docs/PLAN-MODE.md` | convention references |
  | `agent_docs/adr/README.md` | retired with `agent_docs/` (Decision 13) |

- `overview-fresh` assumes a **spec directory** holding `overview.html`, `thoughts.md`, and
  `decisions/`, and greps a `DECISION [0-9]+` high-water mark from it. `LOG.md` is per-worktree, not
  per-spec, so a straight retarget is wrong. This skill needs an explicit keep/retarget/retire call
  in Decision 11.
- `melting-v2/docs/workspace.md` and `melting-v2/docs/agent-environment.md` describe the
  `workspace.md` / `scoping/` / `spec/` / `<utc>-<type>-<uuid>.md` model throughout. Both require
  wholesale rewriting, not patching.
- `HIGH-LEVEL-CONTEXT.md` lines ~208–292 specify typed history subdirectories and a
  `history/README.md`; both must change to the flat convention.
- This document's `.workspace/` contract block and the §"Handoff, verify, and ship" paths
  (`history/handoffs/...`, `history/verification/...`) must change to flat filenames.
- Contradiction 2 (workspace schema) is resolved.
- Depot's `specs/workspace-memory-v1/` and its closed-schema requirements are confirmed dead and
  should be marked superseded rather than left as an apparent alternative.

**Promotion candidates (not promoted):** none.

### DEC-4 — `MISSION.md` schema, states, and mutation rules

**Decision.** `MISSION.md` is deliberately small, unvalidated, and lossy by design:

```markdown
---
state: scoping
spec: null
---

# Mission

## Objective
## Current position
## Next action
## Blockers
```

**Frontmatter is two fields.** `state` is one of `scoping`, `building`, `shipped`, `abandoned`.
`spec` is `null` until binding, then `{path, commit}` (Decision 6).

**Deliberately excluded, with reasons:**

- `workspace_id` — `grep -rn "workspace_id" src/ web/` in Depot returns **zero hits**; control-plane
  V1 removed the field entirely. Nothing on the machine consumes a workspace identity, and inventing
  one would require the harness to run the identity registry DEC-1 just refused to give Depot.
- `project`, `worktree`, `branch` — derivable from git, and they silently go stale when a branch is
  renamed or a worktree moves. Orientation computes them for free.
- `Scope` and `Constraints` sections — before a spec exists they are settled entries in `LOG.md`;
  after it exists they belong to `specs/<slug>.md`. A third copy is a third thing to drift.
- `verified` state — verification is a gate passed before shipping, not a state to sit in.
- `blocked` state — duplicates the Blockers section, and the two can disagree. melting-v2's model
  carries both.

**Anti-burden and anti-conflict properties.** These are load-bearing, not incidental:

1. **Lossy by design.** `MISSION.md` is the only file in `.workspace/` that may be overwritten.
   Because everything durable is append-only in `LOG.md` and `history/`, a clobber by a concurrent
   session costs a stale pointer, never lost work. This is what makes overwrite-in-place safe and is
   the main defence against multi-session conflicts (Decision 7).
2. **Section-scoped writes.** An agent edits the heading it is changing rather than rewriting the
   whole file, narrowing the clobber window further.
3. **Nothing validates it.** There is no schema enforcement, no repair, no "malformed workspace"
   concept, no staleness error. Missing sections are fine; unknown sections are fine; both
   frontmatter fields have defaults. This is a direct rejection of Depot `workspace-memory-v1`'s
   bounded contracts, validation, and `workspace_changed` staleness errors — that machinery is what
   made the model burdensome, and it has been deleted.
4. **Orientation reports, never repairs.** It may report spec drift and how stale `MISSION.md` looks
   relative to the last commit or `LOG.md` entry. It never rewrites the file or changes `state`.

**Update cadence — exactly two obligations:**

> Update `MISSION.md` before anyone else reads it: **before writing a handoff**, and **at session
> end**. Changing `state` or `spec` is that edit by definition. Everything else is opportunistic.

The reasoning is that the expensive part of an update rule is not the write — a section-scoped edit
of a few lines — but the *ambient monitoring* needed to notice a boundary. Both obligations attach
to actions the agent has already deliberately chosen to take, so detection costs nothing. State and
spec changes are not a third obligation: those fields exist nowhere else, so changing them *is* the
edit. Refreshing `Current position` after finishing the stated `Next action`, and recording a new or
cleared blocker, are opportunistic rather than required — `MISSION.md` only has to be true when
another reader arrives, and both obligations fire before that happens.

Residual risk, accepted: a session that dies without reaching either obligation leaves a stale
mission. This is bounded by the lossy-by-design property — the recovering session reads
`git status`, `git log`, and the tail of `LOG.md`, which hold the durable record. A stale pointer is
lost; work is not.

A Stop/SessionEnd hook on both providers may *remind*, but the contract must not be hook-dependent.

**Downstream effects (not yet applied):**

- This document's §2 illustrative `MISSION.md` (six frontmatter fields, six sections) is superseded.
- `HIGH-LEVEL-CONTEXT.md`'s lifecycle list (`scoping → ... → verified → completed or
  abandoned`) and its "identify the repository, branch/workspace, and linked spec" sentence must be
  replaced by the four-state vocabulary and two-field frontmatter.
- `melting-v2/docs/workspace.md`'s `active`/`blocked`/`completed`/`abandoned` states and
  `workspace.md` section list are superseded.
- Contradiction 3 (exact mission contract) is resolved.

**Promotion candidates (not promoted):** none.

### DEC-5 — Scoping/spec lifecycle; `<slug>.scoping.md` is dropped

**Decision.** There is no scoping document. The chain is:

```text
.workspace/LOG.md  →  specs/<slug>.md                        (T0–T2)
.workspace/LOG.md  →  specs/<epic>/README.md + 01-*.md       (T3)
```

Curated framing lives **inside the spec**, in sections that already exist:
`specs/templates/t2/spec.md` carries `## Problem / Solution / User stories`, `## Out of scope`, and
`## Resolved decisions` ("settled scope/behavior from grilling — do NOT re-litigate"). For a T3
epic, the epic `README.md` is "shared context + ordered task list";
`depot/specs/control-plane-v1/README.md` is the working exemplar, carrying Goal, Resolved decisions,
Domain model, and Tasks in one readable file.

`<slug>.scoping.md` was a third home for content those two artifacts already own, and
`HIGH-LEVEL-CONTEXT.md` only ever described it as optional. There is no separate "scoping synthesis"
step; `write-plan` reads `LOG.md` and writes the spec directly, as it does today.

**Retired by this decision** (the current four-surface task-context model in `specs/README.md` and
`.claude/rules/specs.md`):

| Surface | Disposition |
| --- | --- |
| `specs/<slug>.md` | kept — the build contract |
| `specs/<slug>.thoughts.md` | retired → `.workspace/LOG.md` |
| `specs/<slug>.sessions/` | retired → `.workspace/history/<utc>-handoff-<slug>.md` |
| `.context/<slug>.md` | retired → `.workspace/LOG.md` |
| `specs/<slug>.scoping.md` | never created |

Note that this merges two surfaces the current model deliberately separated — the committed
"planning path worth keeping" and the gitignored "scratch to discard" — into one `LOG.md`. The
graduation rule survives intact: anything durable graduates out of `LOG.md` into the spec.

**Accepted cost.** `LOG.md` is untracked and dies with the worktree, so T3 framing evidence is lost
unless promoted into the epic `README.md` before removal. This is accepted; the preservation step is
Decision 8.

**Downstream effects (not yet applied):**

- `HIGH-LEVEL-CONTEXT.md` — remove `<slug>.scoping.md` from the canonical project structure,
  the `specs/` section, the T3 epic shape, the ownership/promotion chain, the source-of-truth table,
  and convergence-audit item 4.
- This document — delete §5 "Synthesize scoping", the `specs/<slug>.scoping.md` source-of-truth row,
  the scoping promotion rule, and step 6 of the recommended workflow.
- `specs/README.md` — its entire "Where context lives" section describes the retired four-surface
  model and must be rewritten.
- `.claude/rules/specs.md` — the "Conclusion, not journey" bullet references `<slug>.thoughts.md`,
  `.context/<slug>.md`, and `agent_docs/`; all three are retired.
- Delete `specs/templates/{t1,t2,t3}/*.context.md`, `specs/templates/t2/spec.thoughts.md`, and
  `specs/templates/t2/spec.sessions/`.
- The T3 epic `README.md` template needs an explicit `## Resolved decisions` section.
- Contradiction 3 (spec companions) is resolved.

**Promotion candidates (not promoted):** none.

### DEC-6 — The spec pointer is one field; the binding apparatus is deleted

**Decision.** `MISSION.md` carries a single frontmatter field:

```yaml
spec: specs/inbox-filtering.md   # null until the task is building
```

It is a plain field the agent writes like any other part of `MISSION.md`. There is no ritual around
it, and the word "bind" leaves the vocabulary — it was ceremony language for one line in a file that
is written anyway.

**Deleted entirely:**

- any `bind` command, skill, or CLI surface (including `depot workspace bind`);
- `make work SPEC=…` and the `.claude/active-spec` pointer;
- the `{path, commit}` source-commit pin;
- drift detection and stale-binding policy;
- any rebind procedure — rebinding is editing the field.

**Rationale.** Binding was a context-injection optimization, not a semantic requirement. The
existing machinery exists because the old model had nowhere else to put the spec path; orientation
now reads `MISSION.md` unconditionally, so the path is discoverable by construction. The commit pin
is separately unjustified: a worktree's spec is whatever is at its own HEAD, so a pin would fire
"drift" mostly on the builder's own legitimate mid-build spec edits, duplicating a version question
git already answers.

**Kept from the existing implementation.** `.claude/hooks/spec-session-orient.sh` already solves
resolution well and should be ported, not rebuilt: branch-name fallback (full branch path, then last
segment), fires on `startup|resume|clear|compact`, fails open, never blocks, and stays silent when
nothing resolves so T0/T1 work gets no nag. Two changes: it reads `MISSION.md`'s `spec:` field
instead of `.claude/active-spec`, and its **self-bind write is removed** — under DEC-4 orientation
never writes, so the branch fallback is display-only.

**Cross-worktree sharing needs no mechanism.** An uncommitted spec in worktree A is invisible to
worktree B because that is how git works. The rule is: commit the spec before creating parallel
build worktrees.

**Downstream effects (not yet applied):**

- Rewrite `.claude/hooks/spec-session-orient.sh` per above; remove its pointer read and self-bind
  write.
- Remove the `work` target from the base `Makefile`; remove `.claude/active-spec` and its
  `.gitignore` entry.
- `.claude/rules/specs.md` — delete the "Bind the worktree to it" bullet.
- `specs/README.md` — delete the "Binding a worktree to its spec" section.
- `HIGH-LEVEL-CONTEXT.md` — delete the `depot workspace bind` paragraph and the stale-binding
  discussion.
- This document — rewrite §7 "Bind the formal spec".
- `melting-v2/docs/workspace.md`'s note that `make work` writes a now-inert pointer is resolved by
  deletion.
- Contradictions 7 (spec drift) and 8 (parallel access) are resolved.

**Promotion candidates (not promoted):** none.

### DEC-7 — No concurrency protocol

**Decision.** Multiple Claude/Codex sessions in one worktree share the checkout, branch, and
`.workspace/`. There is **no locking, no append protocol, and no staleness check.** The risk of a
lost `LOG.md` entry is accepted; it should rarely occur on a single-human machine where sessions are
driven one conversation at a time. Revisit only if it actually happens.

This is safe because the exposure is already structurally small:

- `history/` records are immutable, one file per record, UTC-prefixed and uniquely named — two
  sessions **cannot** collide there;
- `MISSION.md` is lossy by design (DEC-4), so a clobber costs a stale pointer, never work;
- DEC-6 removed the hook's self-bind write, eliminating one concurrent-writer path;
- `LOG.md` is therefore the only file with genuine concurrent-write exposure.

Depot will not arbitrate: `control-plane-v1/README.md` states that a worktree may contain many
concurrent sessions and writers, and that Depot "exposes that concurrency and does not impose
workflow semantics or pretend to prevent file-level conflicts." Depot's deleted
`workspace-memory-v1` took the opposite approach — `observed updated_at` checks returning
`workspace_changed` — and DEC-4 explicitly rejected reviving it.

**Cross-worktree coordination** requires no mechanism. Separate worktrees have separate
`.workspace/` directories; coordination happens through committed specs, the issue tracker, and PRs.

**Downstream effects (not yet applied):**

- `HIGH-LEVEL-CONTEXT.md` and this document should state the no-protocol position explicitly
  rather than leaving locking "not yet specified".
- Contradiction 9 (concurrency) is resolved.

**Promotion candidates (not promoted):** none.

### DEC-8 — Handoffs, findings, archival, removal, and promotion

**Decision.** There is **no enforcement machinery**. No finding status fields, no pre-removal
checklist, no export or archive step. `.workspace/` is disposable by default, and worktree removal
carries zero obligation — Depot's existing guarded trash is unchanged and remains the removal
mechanism.

This also dissolves rather than patches the immutability contradiction: the earlier proposal gave
findings a mutable `open` / `resolved` / `promoted` / `wont-fix` status, which cannot coexist with
DEC-3's immutable `history/` records. With no status field, nothing mutable ever touches a record.

**Promotion is a conversation between the agent and the developer, in two forms:**

1. **Opportunistic, any time.** An agent that notices something worth promoting to the repository —
   an ADR, a glossary entry, an architecture correction, an issue — *says so and asks*. It never
   creates one silently. This matches the constraint `HIGH-LEVEL-CONTEXT.md` already places on
   `grill-with-docs`.
2. **At merge.** The promotion conversation happens when the PR is merged, because that is when the
   decision is real. **The promotion itself ships as a separate PR**, so durable documentation never
   blocks shipping the code.

**Consequent requirement on the shipping workflow (Decision 14).** Because the worktree — and
`LOG.md` with it — may be gone by merge time, **the PR description must carry the settled decisions
from `LOG.md`.** The PR body is the bridge: it survives the worktree, it is what the developer is
looking at when merging, and it is what makes a merge-time promotion conversation possible at all.
Keeping the worktree until that conversation is done is the natural practice, but the PR body is the
durable mechanism.

**Handoff records** keep the existing skill's content shape (Summary, Key decisions, **What did NOT
work**, Code changes, Open questions/blockers, Next steps), moving from the committed numbered
`specs/<slug>.sessions/NNN_<summary>.md` to `.workspace/history/<utc>-handoff-<slug>.md`.

**Accepted cost.** A worktree deleted without a merge conversation loses its findings.

**Downstream effects (not yet applied):**

- `.claude/skills/handoff/SKILL.md` — retarget "Where it goes" from `specs/<slug>.sessions/NNN_*.md`
  to `.workspace/history/<utc>-handoff-<slug>.md`; the `NNN` sequence becomes a UTC timestamp.
- The shipping skill must compose the PR description from `LOG.md`'s settled decisions.
- This document's §11 "Findings and cleanup" — delete the status vocabulary and the preservation
  requirement.
- `HIGH-LEVEL-CONTEXT.md` — delete the finding-status sentence and the promotion-before-removal
  expectation.
- Contradictions 10 (cleanup) and 13 (promotion) are resolved.

**Promotion candidates (not promoted):** none.

### DEC-9 — Canonical machine hierarchy, `~/agents/`, and secrets

**Decision.** `~/.agents/` is the single canonical provider-neutral **source** tree. `~/agents/` is
retired. Machine-level secrets move to `~/.config/agents/secrets.env`.

```text
~/.agents/                       canonical source: skills/, agents/, rules/, hooks/
~/.claude/                       real directory: Claude runtime state + thin adapter
~/.codex/                        real directory: Codex runtime state + thin adapter
~/.config/agents/secrets.env     machine-level secrets (chmod 600, sourced from ~/.zshrc)
```

Provider homes symlink individual source subdirectories (e.g. `~/.claude/skills → ~/.agents/skills`)
rather than the whole tree.

**Observed machine state that drove this:**

| Surface | `~/agents/claude` (= `~/.claude`) | `~/.codex` | `~/.agents` |
| --- | --- | --- | --- |
| skills | 20 | 9 | 11 |
| agents | 4 × `.md` | 4 × `.toml` | — |
| commands | `ship.md` | — | — |
| rules | 4 files | `rules/` | — |
| hooks | `inject-global-rules.sh` | `hooks/` + `hooks.json` | — |
| config | `settings.json` | `config.toml` | — |
| runtime state + secrets | yes | yes | **no** |

1. **`~/.agents/skills` and `~/.codex/skills` are disjoint, and their union is exactly the Claude
   set** (11 + 9 = 20, matching except `hot-mac` vs `hatch-pet`). `~/.agents/` is *already*
   functioning as a provider-neutral skills root that Codex reads. Naming it canonical formalizes
   what works rather than inventing a layout.
2. **`~/agents/` has a weak claim.** `~/agents/codex` and `~/agents/hermes` are empty;
   `~/agents/conductor` holds another tool's archived contexts. The `~/.claude → ~/agents/claude`
   symlink did not create a canonical source — it relocated the entire Claude home, runtime state
   included (`sessions/`, `cache/`, `history.jsonl`, `projects/`, `shell-snapshots/`, `telemetry/`).
3. **`~/agents/` and `~/.agents/` differ by one character** while meaning completely different
   things. Retiring one name eliminates a real write-to-the-wrong-tree failure mode instead of
   documenting around it.

**`~/agents/` disposition:** `claude/` moves back to a real `~/.claude/`; the empty `codex/` and
`hermes/` are deleted; `conductor/archived-contexts/` moves to `~/.conductor/archived-contexts/`.

**Secrets.** There are two tiers, governed differently:

| Tier | What | Where | Provisioned by |
| --- | --- | --- | --- |
| Machine/personal | keys used across projects; inherited by every agent process via the shell | `~/.config/agents/secrets.env` | manually |
| Project | app runtime config | the project's own `.env` convention, gitignored | `make setup` (Slot 1) |

The harness **never writes either** and only ever references `${VAR}`. It defines no location for
project secrets; each project owns that.

Verified: no `secrets.env` exists anywhere except the machine one, and no `.env` file exists under
any project's `.claude/`. The five project `.env` files found (`melting/code/v1/.env` and four under
`dev/archive/`) are application config, not harness secrets.

⚠ **The governing invariant:** machine secrets must never live in a tree that is a candidate for
versioning or syncing. `~/.agents/` is now exactly that tree, so `~/.agents/secrets.env` is ruled
out. `~/.claude/secrets.env` would be technically safe but semantically wrong — a machine-wide
secret in a provider directory, one character from `~/.agents/`.

**Downstream effects (not yet applied):**

- ⚠ **Migration risk:** undoing `~/.claude → ~/agents/claude` moves Claude's live runtime state
  (`sessions/`, `plugins/`, `history.jsonl`, `projects/`). This is the riskiest step in the machine
  migration and must run with no Claude session active.
- `~/.zshrc` — update the `secrets.env` source path.
- `~/.agents/rules/00-preferences.md` and `secrets.md` both name `~/.claude/secrets.env` and must be
  updated. (These are the same files currently at `~/agents/claude/rules/`.)
- `HIGH-LEVEL-CONTEXT.md` and `specs/harness-standardization/plan/tasks.md` both name
  `~/agents/` as the canonical root and must be rewritten to `~/.agents/`.
- The 20/9/11 skill split must be reconciled into one canonical set (Decision 11).
- The four Codex agents are `.toml` while Claude's are `.md`; a canonical `agents/` source needs a
  parity answer (Decision 12).

**Promotion candidates (not promoted):** none.

### DEC-10 — Layering, and the criterion that decides placement

**Decision.** Three layers, with placement decided by **portability**, not frequency:

> **The core test:** would this be correct and useful in a repository I have never seen, with zero
> configuration?

| Layer | Test | Home |
| --- | --- | --- |
| Universal core | passes the core test | `~/.agents/{skills,agents,rules,hooks}`, versioned in the harness repo |
| Project layer | needs project facts (gates, tracker, domain, conventions) | the repo's `.claude/` + `docs/agent-guidance/` |
| Area pack | domain-specific tooling (frontend, browser, docs, data) | opt-in per project or provider; **never global** |

Portability was chosen over frequency because it is testable by inspection, so classification does
not need re-litigating skill by skill. "Frequently used" is unfalsifiable and drifts — which is
precisely how the current machine ended up with everything global. The criterion has real bite: it
moves `ship` down to the project layer (it depends on the project's gate and PR conventions) while
keeping `adopt-harness` in core (portable, if rarely used).

**Evidence — the layering already exists de facto.** The harness repo's `.claude/skills` contains
**exactly** the 11 skills in `~/.agents/skills`, pushed there by `make install-global`. Agents (4)
and commands (1) are at full parity between harness repo and machine. Rules are deliberately split,
as the base `Makefile` states: "rules and hooks are split-purpose (harness ships project-scoped
versions; global has your personal/wired ones)" — harness ships `migrations.md` and `specs.md`;
the machine holds preferences, secrets, and scratch-work. The structure is right; Claude just
flattens all 20 skills into one directory and loses the distinction.

**Two problems this exposes:**

1. **Nine skills have no source of truth** — `domain-modeling`, `grill-with-docs`, `grilling`,
   `hatch-pet`, `prototype`, `research`, `setup-matt-pocock-skills`, `teach`, `wayfinder` exist only
   on disk in `~/.codex/skills`, unversioned and unbacked. Each must be classified into a layer or
   retired (Decision 11).
2. **Area packs are globally always-on, contradicting the model.** `frontend-design` is enabled
   globally on *both* providers, and `~/.codex/config.toml` additionally enables ten always-on
   plugins (visualize, google-calendar, slack, sites, documents, pdf, spreadsheets, presentations,
   template-creator, browser).

**Downstream effects (not yet applied):**

- `make install-global` must distinguish core from project-layer content rather than pushing
  `.claude/{skills,agents,commands}` wholesale.
- Every currently-global area pack becomes opt-in. ⚠ Verify in Decision 12 whether Codex's plugin
  model supports anything other than global enablement; if not, "opt-in per project" is not
  achievable there and needs an explicit exception.
- `HIGH-LEVEL-CONTEXT.md`'s machine-layer section should state the portability test explicitly
  rather than listing example skills.
- Contradiction 11 (skill parity) is scoped by this decision and resolved in Decisions 11–12.

**Promotion candidates (not promoted):** none.

### DEC-11 — The skill and agent catalog

**Decision.** Applying DEC-10's portability test to all 20 skills, 4 agents, and 1 command:

| Layer | Contents |
| --- | --- |
| **Core** (`~/.agents/`) | `brainstorm`, `diagnose`, `tdd`, `verify-before-done`, `handoff`, `write-plan`, `adopt-harness`, `prototype`, `research`, `docs-drift`, `grill`; agents: `scout`, `researcher`, `reviewer`, `reviewer-security` |
| **Project layer** | `ship` / `open-a-pr` (needs the gate and PR conventions), `wayfinder` (needs an issue tracker), `setup-matt-pocock-skills`, `domain-modeling` |
| **Area pack** (opt-in) | `teach`, `frontend-design`, and the browser/visualize/documents plugin family |
| **Retire** | `overview-fresh`, `hatch-pet`, `grill-me`, `grilling`, `grill-with-docs` (superseded by `grill`) |

**The grill collapse.** Three overlapping skills with near-identical triggers — `grill-me`
(harness/core), `grilling` and `grill-with-docs` (unversioned) — become one core skill, `grill`. It
keeps `grill-me`'s one-decision-at-a-time discipline and `grill-with-docs`'s grounding in repository
documentation, but **strips the automatic doc creation**. Reading `docs/` when present is portable
and needs no project configuration, so the merged skill stays in core.

**Conflicts resolved by this decision:**

1. `grill-with-docs` is described as "a relentless interview ... which also creates docs (ADRs and
   glossary) as we go." That is precisely the behavior DEC-8 outlawed. The merged `grill` **proposes
   ADR/glossary candidates and asks**; it never writes them.
2. `overview-fresh` is retired: DEC-5 deleted the spec directory holding `overview.html`,
   `thoughts.md`, and `decisions/` from which it greps a `DECISION [0-9]+` high-water mark. Its
   premise no longer exists.
3. `research` writes "findings as a Markdown file in the repo"; retarget to
   `.workspace/history/<utc>-finding-<slug>.md` per DEC-3.
4. `open-a-pr` versus `ship` remains open — contradiction 15, resolved in Decision 14.

**Correction to an earlier observation in this review.** `grill-with-docs`, `teach`, `wayfinder`,
and `setup-matt-pocock-skills` are absent from Claude's auto-loaded skill set because they carry
`disable-model-invocation: true` — they are deliberately user-invocable only (`/name`). This is
configuration, not drift or breakage.

**Downstream effects (not yet applied):**

- Author `grill` in the harness repo; delete `grill-me`, `grilling`, `grill-with-docs`.
- Delete `overview-fresh` and its references; confirm and delete `hatch-pet` (Codex-only).
- Version the retained unversioned skills (`prototype`, `research`, `domain-modeling`, `wayfinder`,
  `setup-matt-pocock-skills`, `teach`) into the harness repo at their assigned layer — they
  currently exist only on disk in `~/.codex/skills`.
- Move `ship`/`open-a-pr` out of the machine layer into the project layer.
- Retarget `research`'s output path.
- `.claude/skills/VENDORED.md` must be updated for every merge, retirement, and retarget.

**Promotion candidates (not promoted):** none.

### DEC-12 — Provider parity, hooks, plugins, LSP, and the security-review policy

**a) Skills — already portable.** Both providers read `SKILL.md` directories in the same format.
No parity work is required.

**b) Hooks — full parity is achievable and must be built.** The Codex binary contains
`PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `Stop`, `SessionEnd`, and `PreCompact` — the same
event vocabulary as Claude — and `~/.codex/hooks.json` uses the same JSON schema shape as
`settings.json`. The harness's six safety hooks (`block-default-branch-commit`,
`block-dangerous-bash`, `protect-secrets`, `flag-comment-bloat`, `enforce-gate-on-stop`,
`collab-reminders`) can therefore register on both.

⚠ This is the most material gap found in the machine audit: **Codex sessions currently run with only
`inject-global-rules.sh` and no safety hooks at all** — no default-branch protection, no
dangerous-command blocking, no secret protection.

**c) Agents — divergent formats are accepted.** Claude uses `.md` with YAML frontmatter; Codex uses
`.toml` with a `developer_instructions` block. A diff of `reviewer-security` shows the content is
identical and only the container differs. **Decision: keep both formats and dual-maintain them.** No
generator. Accepted cost: the two can drift. Mitigation: there are only four agents, and their
bodies should stay short enough that divergence is cheap to spot.

**d) Plugins and LSP.** `~/.codex/config.toml` enables eleven plugins globally, and its
`[projects."…"]` sections carry only `trust_level` — no per-project plugin key exists. Codex plugin
enablement appears **global-only**, which is an accepted exception to DEC-10's "area packs are never
global." LSP arrives via language-specific official plugins that activate automatically
(`research/SKILL-CATALOG-RESEARCH-2026-08.md:76`); global enablement is harmless because a language
plugin is inert without a matching language.

**e) Security review — pin the strongest tier.** Claude's `reviewer-security` moves from
`model: sonnet` to `opus`; Codex's continues to inherit `gpt-5.6-luna` at
`model_reasoning_effort = "max"`. The agent's stated job is "the failure modes that are silent and
expensive"; a gate weaker than the model that wrote the code is the wrong way round, and it runs
only on risk hotspots, so the cost is bounded. Inheriting the session model was rejected because
coding and reviewing with the same model yields no independent perspective.

**Additional review gate: `/code-review ultra`.** A multi-agent cloud review of the branch or a PR.
It is **complementary to, not a substitute for, `reviewer-security`**: `code-review` is broad
correctness and quality across the diff; `reviewer-security` is the narrow adversarial risk lens for
hotspots. Critically, `/code-review ultra` is **user-triggered and billed — an agent cannot launch
it** — so it belongs in the journey as a gate the developer runs, never as an automated step
(Decision 14). A Codex equivalent should be investigated later; none is currently identified.

**Downstream effects (not yet applied):**

- Register the six safety hooks in `~/.codex/hooks.json`, matching `~/.claude/settings.json`.
- Change `model: sonnet` → `opus` in `reviewer-security.md`; leave the Codex `.toml` unchanged.
- Record the Codex global-plugin exception in the machine contract so it is not read as drift.
- Decision 14 must treat `/code-review ultra` as a human-invoked gate.
- Contradictions 11 (skill parity) and 14 (security model) are resolved.

**Promotion candidates (not promoted):** none.

### DEC-13 — One documentation namespace; planning artifacts live with their epic

**Decision.**

- **`docs/` holds durable repository truth only**: `INDEX.md`, `architecture.md`, `glossary.md`,
  `adrs/`, `agent-guidance/`. `docs/` is flat and `INDEX.md` routes.
- **Planning and research artifacts live under `specs/<epic>/`**, with the work they inform. This
  follows DEC-5's principle that framing belongs with its spec rather than in a separate namespace.
  Planning artifacts age out with their epic instead of accumulating as permanent documentation.
- **`agent_docs/` is retired everywhere.**
- **No new `building/` namespace.** `specs/` stays as it is, and melting-v2's existing `specs/`
  layout is left in place — restructuring it is explicitly out of scope.

**Evidence — three repos, three situations:**

| Repo | `agent_docs/` | `docs/` |
| --- | --- | --- |
| agentic-engineering | adr/, architecture.md, glossary.md | ten research/reference essays; no canonical trio |
| depot | nine files | **empty** |
| melting-v2 | adr/, architecture.md, glossary.md, revisit.md, overview.html | adrs/, architecture.md, glossary.md, revisit.md |

⚠ **melting-v2 has live, divergent duplication.** Diffed:

| File | `agent_docs/` | `docs/` | |
| --- | --- | --- | --- |
| architecture.md | 75 lines | 55 lines | **DIFFERENT** |
| glossary.md | 65 lines | 24 lines | **DIFFERENT** |
| revisit.md | 153 lines | 9 lines | **DIFFERENT** |

Two architecture manuals, two glossaries, and two decision logs, all disagreeing — exactly what
`HIGH-LEVEL-CONTEXT.md`'s north star forbids, happening today.

⚠ **Migration hazard.** The retirement cannot be "delete `agent_docs/`, keep `docs/`." In every
duplicated pair the `agent_docs/` copy is substantially **larger**; the `docs/` copies look like
stubs from a partial migration that was never finished. A bulk move loses most of the content.
**Reconciliation must be per-file, with a human, choosing or merging.** `depot` is a clean rename;
`agentic-engineering` is a clean move; only `melting-v2` needs real merging.
`agent_docs/overview.html` disappears with `overview-fresh` (DEC-11).

**Per-file disposition for `agentic-engineering/docs/` (needs individual calls, not a bulk move):**

| File | Likely disposition |
| --- | --- |
| `HARNESS-DEPOT-OPERATIONAL-DESIGN-REVIEW.md` | → `specs/harness-standardization/` |
| `HIGH-LEVEL-CONTEXT.md` | → `specs/harness-standardization/` — it is the target being implemented |
| `SKILL-CATALOG-RESEARCH-2026-08.md` | → `specs/harness-standardization/` (research input) |
| `ARCHITECTURE-REVIEW-2026-07.md`, `DOCUMENTATION-ARCHITECTURE-RESEARCH-2026-07.md` | **retire** — superseded by `HIGH-LEVEL-CONTEXT.md` |
| `OVERLAY-CONTRACT.md` | likely durable — describes the live slot system → `docs/architecture.md` |
| `AGENT-ANTIPATTERNS.md`, `CLAUDE-CODE-RULES.md`, `PLAN-MODE.md`, `SOURCES.md` | per-file call |

**melting-v2 `specs/` residue, left in place:** five orphaned `*.sessions/` directories whose parent
spec files no longer exist (`11-chat-transport`, `16-profile-onboarding`, `18-runner`,
`g2-substrate-cutover`, `g3-merge-machinery-closeout`) and a `specs/.context/`. All are retired
conventions under DEC-5, but deleting them is optional cleanup, **not** part of this migration.

**Downstream effects (not yet applied):**

- Making this review the canonical implementation handoff means moving it to
  `specs/harness-standardization/`.
- `HIGH-LEVEL-CONTEXT.md` states that `docs/agent-guidance/` and a single `docs/` namespace are
  the target but does not say where planning artifacts go; add the `specs/<epic>/` rule.
- Eleven files in the harness `.claude/` tree reference `agent_docs/` and must be retargeted.
- Contradiction 4 (documentation namespace) is resolved.

**Promotion candidates (not promoted):** none.

### DEC-14 — The verification and shipping workflow

**Decision.** Two mandatory local steps, then the PR. Review happens on the PR, not locally.

```text
LOCAL, before the PR
  1. make check           already hook-enforced by enforce-gate-on-stop.sh
  2. verify-before-done    run it, exercise it, report evidence
  3. /ship → open-a-pr     gate pre-flight → description → gh pr create

ASYNC
  4. the project's PR review bot reviews the diff

HUMAN, optional
  5. /code-review on load-bearing paths before opening — private iteration
  6. merge-time promotion conversation (DEC-8) → ships as a separate PR
```

`reviewer` and `reviewer-security` **leave the mandatory flow** and remain explicitly invocable.
Their remaining real use is private pre-push scrutiny of a sensitive change that should not be
public in draft. E2E stays explicit and project-layer, invoked only when the project requires it.

Per DEC-8, `open-a-pr` composes the PR description from `LOG.md`'s settled decisions, because the
PR body is what survives the worktree and enables the merge-time promotion conversation.

**Rationale, from delegated research into 2026 practice:**

- For a solo developer with a capable PR bot, running local review agents before every PR duplicates
  what the bot does minutes later. Indicative (unverified) cost figures: ~$15–30/PR with a bot alone
  versus ~$50–100 when stacking local agents.
- **PR bots systematically never run the code.** They read the diff and infer behavior statically.
  `verify-before-done` covers exactly that gap, which is why it is the one local step that is not
  redundant — and it is not a review.
- **The independence problem:** when the same model writes and reviews, a green result signals
  consistency rather than correctness. This argues for the PR bot being a different model from the
  one that wrote the code.

⚠ The research reported specific launch dates and per-review pricing at medium confidence and could
not verify several claims. The contract must not depend on those numbers.

**Contradiction 15 was already false.** `ship` and `open-a-pr` are not competing surfaces:
`.claude/commands/ship.md` is a thin trigger that checks git state and then states "follow the
open-a-pr skill exactly … The single source of truth for the procedure is that skill — do not
reinvent the steps here." One procedure, one trigger. No change needed.

**PR review configuration is project-layer and provider-agnostic.** The harness contract does not
name a bot, a model, or a provider. The reference implementation already exists at
`smoke-screen/.github/workflows/claude-code.yml` — `anthropics/claude-code-action@v1`, triggered on
`pull_request`, `issue_comment`, and `pull_request_review_comment`, authenticated with a GitHub App
token. melting-v2 replicates the same pattern. Which provider backs the bot is a project choice and
is deliberately left out of the harness contract.

**Downstream effects (not yet applied):**

- This document's §10 seven-step pre-ship sequence is superseded by the three local steps above.
- `HIGH-LEVEL-CONTEXT.md`'s shipping guidance must match.
- `open-a-pr` gains the "compose the description from `LOG.md` decisions" step.
- Contradiction 15 is closed as a non-issue.

**Promotion candidates (not promoted):** none.

### DEC-15 — The day-to-day journey, and how `.workspace/` is ignored

**Decision.** The reconciled journey is recorded in full in the next section. The one mechanical gap
it exposed is settled here: **`.workspace/` is excluded via the global gitignore
(`~/.config/git/ignore`)**.

One line, machine-wide, zero per-repo work, and it covers repositories that never adopt the harness.
`.workspace/` is machine-local by design, so a machine-local exclude is the honest match. A committed
per-repo `.gitignore` entry was rejected because it requires touching every repository and
advertises a convention collaborators do not share; a per-worktree `.git/info/exclude` was rejected
as invisible when debugging why a path is ignored.

Depot's deleted model used "a shared Git exclude marker"; that mechanism disappeared with DEC-1 and
this replaces it.

**Downstream effects (not yet applied):**

- Add `.workspace/` to `~/.config/git/ignore`.
- No repository `.gitignore` gains a `.workspace/` entry.

**Promotion candidates (not promoted):** none.

---

## Reconciled target workflow

```text
 1  wt <project> --branch <b>      git worktree add → .workspace/ init → make setup     DEC-1,2
    (or Depot UI/phone creates it git-only; .workspace/ appears at step 2)

 2  claude | codex                 SessionStart: ensure-workspace.sh (idempotent init),
                                   inject-global-rules.sh, spec-orient (read-only)      DEC-2,6

 3  "orient me"                    reads MISSION.md + git-derived repo/branch;
                                   reports drift, never repairs                          DEC-4

 4  brainstorm → grill             one decision at a time, grounded in docs/,
                                   proposes promotion candidates, never writes them
                                   → ordered DECISION/QUESTION entries in .workspace/LOG.md
                                   → findings in history/<utc>-finding-<slug>.md         DEC-3,8,11

 5  write-plan                     reads LOG.md → specs/<slug>.md  (T0–T2)
                                   or specs/<epic>/README.md + 01-*.md  (T3)
                                   framing lives IN the spec; no scoping doc             DEC-5

 6  MISSION.md                     state: building   spec: specs/<slug>.md               DEC-6

 7  build                          reads AGENTS.md, adapter, project docs, MISSION.md,
                                   the spec — not the whole history.
                                   tdd for new logic; diagnose for hard bugs.
                                   many sessions may share the worktree; no locking      DEC-7,11

 8  handoff (when needed)          update MISSION.md, then
                                   history/<utc>-handoff-<slug>.md                       DEC-4,8

 9  make check → verify-before-done → /ship                                              DEC-14
                                   open-a-pr: gate pre-flight → description composed
                                   from LOG.md decisions → gh pr create

10  PR bot reviews                 async, project-configured, provider-agnostic          DEC-14

11  merge + promotion conversation what's worth an ADR / glossary / architecture /
                                   issue? → ships as a SEPARATE PR                       DEC-8

12  cleanup                        Depot's guarded trash. .workspace/ dies with the
                                   worktree. No export, no archive, no checklist         DEC-8
```

`MISSION.md` is written at exactly two moments: before a handoff and at session end.

**The invariants this rests on:**

| Surface | Property |
| --- | --- |
| `MISSION.md` | two frontmatter fields, four prose sections, unvalidated, **lossy by design** |
| `LOG.md` | ordered DECISION/QUESTION entries; the only file with concurrent-write exposure |
| `history/` | immutable, `<utc>-{handoff,finding}-<slug>.md`, structurally conflict-free |
| `.workspace/` | untracked, per-worktree, disposable; Depot never touches it |
| `specs/` | one spec per task; framing lives inside it; no companions |
| `docs/` | durable repository truth only |
| `~/.agents/` | canonical provider-neutral source; no runtime state, no secrets |

## Conflicting documents

Every document that must change. Nothing below has been modified.

**`agentic-engineering` — contract and plan**

| Document | Conflict |
| --- | --- |
| `HIGH-LEVEL-CONTEXT.md` | Depot ownership; `depot worktree/workspace` commands; `<slug>.scoping.md`; `thoughts.md`; typed history subdirectories + `history/README.md`; five-state lifecycle; `{path, commit}` binding and drift; finding status; promotion-before-removal; `~/agents/` as canonical root; machine core listed by example rather than by the portability test; no rule for planning-artifact placement |
| `specs/harness-standardization/plan/tasks.md` | lines ~204–216 require the four `depot` commands; resolved-direction bullets assume `scoping.md` and `thoughts.md`; internal contradiction with line ~299 |
| `specs/README.md` | the entire four-surface "Where context lives" model; "Binding a worktree to its spec" |
| `.claude/rules/specs.md` | `make work` bind bullet; `<slug>.thoughts.md`; `.context/`; `agent_docs/` |
| `Makefile` | `work` target; `install-global` pushes `.claude/{skills,agents,commands}` wholesale with no core/project-layer distinction |
| `specs/templates/{t1,t2,t3}/` | `*.context.md`, `spec.thoughts.md`, `spec.sessions/`; T3 `README.md` needs a `## Resolved decisions` section |
| `agent_docs/` | retired → `docs/` |
| `research/ARCHITECTURE-REVIEW-2026-07.md`, `research/DOCUMENTATION-ARCHITECTURE-RESEARCH-2026-07.md` | superseded — retire |
| `docs/OVERLAY-CONTRACT.md`, `AGENT-ANTIPATTERNS.md`, `CLAUDE-CODE-RULES.md`, `PLAN-MODE.md`, `SOURCES.md` | per-file call: durable → `docs/`, planning → `specs/harness-standardization/`, stale → retire |

**`agentic-engineering` — skills, agents, hooks**

| File | Change |
| --- | --- |
| `.claude/skills/grill-me/`, `grilling/`, `grill-with-docs/` | merge into one `grill`; delete the three |
| `.claude/skills/overview-fresh/` | retire — premise removed by DEC-5 |
| `.claude/skills/brainstorm/SKILL.md` | Brainstorm thread + `DECISION` entries → `.workspace/LOG.md` |
| `.claude/skills/write-plan/SKILL.md` | reads `.workspace/LOG.md`; no scoping doc |
| `.claude/skills/handoff/SKILL.md` | `specs/<slug>.sessions/NNN_*.md` → `.workspace/history/<utc>-handoff-<slug>.md` |
| `.claude/skills/research/` (unversioned) | output → `.workspace/history/<utc>-finding-<slug>.md` |
| `.claude/skills/open-a-pr/SKILL.md` | compose the description from `LOG.md` decisions; move to project layer |
| `.claude/skills/adopt-harness/{SKILL.md,copy.sh}` | `agent_docs/` references |
| `.claude/skills/VENDORED.md` | update for every merge, retirement, retarget |
| `.claude/agents/{scout,researcher}.md` | `agent_docs/` references |
| `.claude/agents/reviewer-security.md` | `model: sonnet` → `opus` |
| `.claude/hooks/spec-session-orient.sh` | read `MISSION.md` `spec:`; **remove the self-bind write**; keep branch fallback as display-only |

**`depot`**

| Document | Conflict |
| --- | --- |
| `specs/control-plane-v1/README.md`, `agent_docs/adr/0004` | **none — confirmed correct and load-bearing for DEC-1** |
| `specs/workspace-memory-v1/` | dead; mark superseded so it does not read as a live alternative |
| `agent_docs/` | retired → `docs/` (clean rename; `docs/` is empty) |
| *(new)* | `post_create_cmd` sub-spec — additive, **non-blocking** |

**`melting-v2`**

| Document | Conflict |
| --- | --- |
| `docs/workspace.md` | wholesale rewrite — asserts Depot creates/validates/archives/repairs `.workspace/` and that Depot's `workspace` CLI is the intended path; describes the `workspace.md`/`scoping/`/`spec/` schema |
| `docs/agent-environment.md` | wholesale rewrite — "Depot initializes this tree", "Depot owns the workspace-memory lifecycle", old schema |
| `agent_docs/` vs `docs/` | ⚠ **live divergence** — architecture 75 vs 55, glossary 65 vs 24, revisit 153 vs 9 lines, all DIFFERENT. Per-file human merge; the larger `agent_docs/` copy usually holds the content |
| `agent_docs/overview.html` | delete with `overview-fresh` |
| `specs/` residue | five orphaned `*.sessions/` dirs and `.context/` — **left in place**, optional cleanup only |
| `.github/workflows/` | add a PR-review workflow modelled on `smoke-screen/.github/workflows/claude-code.yml` |

**Machine**

| Target | Change |
| --- | --- |
| `~/.claude` | symlink → real directory; runtime state only |
| `~/agents/` | retired; `conductor/archived-contexts/` → `~/.conductor/` |
| `~/.agents/` | canonical source: `skills/`, `agents/`, `rules/`, `hooks/` |
| `~/.config/agents/secrets.env` | new home for machine secrets |
| `~/.zshrc` | update the secrets source path |
| `~/.agents/rules/{00-preferences,secrets}.md` | both name `~/.claude/secrets.env` |
| `~/.codex/hooks.json` | register the six safety hooks — currently Codex has **none** |
| `~/.config/git/ignore` | add `.workspace/` |

## Migration sequence

**Wave 0 — harness repo authoring.** No machine changes; fully reversible; unblocks everything else.

1. Import the nine unversioned skills into the harness repo at their DEC-11 layer — **they exist only on disk in `~/.codex/skills` and are lost if the machine tree is rebuilt first.**
2. Author `grill`; delete `grill-me`, `grilling`, `grill-with-docs`, `overview-fresh`.
3. Retarget `brainstorm`, `write-plan`, `handoff`, `research` to `LOG.md` / `history/`.
4. Write `wt` and `ensure-workspace.sh`.
5. Rewrite `spec-session-orient.sh`; remove the `Makefile` `work` target; delete the template companions.
6. `reviewer-security` → `opus`.
7. Rewrite `specs/README.md` and `.claude/rules/specs.md`.
8. Reconcile `agent_docs/` → `docs/`; retire superseded essays; move planning artifacts to `specs/harness-standardization/`, including this document.
9. Rewrite `HIGH-LEVEL-CONTEXT.md` and `tasks.md` against the DEC entries.

**Wave 1 — machine.** Highest risk. Run with **no live Claude session**.

10. `~/.config/git/ignore` += `.workspace/`.
11. Establish `~/.config/agents/secrets.env`; update `~/.zshrc` and both rule files.
12. Undo the `~/.claude` symlink; establish `~/.agents/` as canonical; symlink provider subdirectories.
13. Retire `~/agents/`; move Conductor archives.
14. Register the six safety hooks in `~/.codex/hooks.json`.

**Wave 2 — projects.**

15. `depot`: `agent_docs/` → `docs/`; mark `workspace-memory-v1` superseded.
16. `melting-v2`: per-file documentation merge; rewrite `workspace.md` and `agent-environment.md`; add the PR-review workflow.
17. **End-to-end verification:** create a worktree with `wt`, orient, scope through `grill`, write a spec, build, ship, merge, promote, remove.

**Wave 3 — deferred, non-blocking.**

18. Depot `post_create_cmd` sub-spec.
19. Investigate a Codex equivalent of the PR-review bot.

## Blockers

1. **Three components do not exist and must be written before the journey works:** `wt`, `ensure-workspace.sh`, and the merged `grill` skill.
2. ⚠ **Ordering hazard:** the nine unversioned skills live only in `~/.codex/skills`. Wave 1 must not run before Wave 0 step 1 or they are lost.
3. ⚠ **Chicken-and-egg:** Wave 1 step 12 moves Claude's live runtime state (`sessions/`, `plugins/`, `history.jsonl`, `projects/`) and requires no live Claude session — but the migration is being performed by Claude. This step needs a shell script run outside a session, or a Codex session.
4. **`melting-v2`'s documentation merge needs human per-file decisions** and cannot be automated; the naive direction loses the majority of the content.
5. **Codex plugin enablement appears global-only** — an accepted exception to DEC-10, recorded so it is not later read as drift.
6. **Unverified:** the research behind DEC-14 reported launch dates and per-review pricing at medium confidence. The contract does not depend on them, but they should not be quoted as fact.
7. **Not blocking:** Depot's `post_create_cmd` and a Codex PR-review equivalent are both additive.

## Contradictions and ambiguities

> **All fifteen are resolved.** 1, 5, 6 → DEC-1/DEC-2. 2 → DEC-3. 3 → DEC-4/DEC-5. 4 → DEC-13.
> 7, 8 → DEC-6. 9 → DEC-7. 10, 13 → DEC-8. 11 → DEC-10/DEC-11/DEC-12. 12 → DEC-11. 14 → DEC-12.
> 15 → closed as a non-issue by DEC-14 (`ship` already delegates to `open-a-pr`). Retained below as
> the original statement of the problem.

1. **Depot ownership:** the harness standard requires semantic Depot workspace commands; Depot control-plane V1 forbids them.
2. **Workspace schema:** `MISSION.md`/`thoughts.md` conflicts with Melting's `workspace.md`/`scoping/`/`spec/` model.
3. **Spec companions:** `.workspace/thoughts.md` conflicts with committed `specs/<slug>.thoughts.md`, `.context/`, and `.sessions/`.
4. **Documentation namespace:** the target retires `agent_docs/`, but current repositories and skills still use it.
5. **CLI reality:** the proposed `depot worktree create`, `workspace init`, `workspace orient`, and `workspace bind` commands are not in the current CLI.
6. **Setup ownership:** the target says Depot invokes project setup; Depot V1 says automatic setup is out of scope.
7. **Spec drift:** source-commit binding is proposed, but stale-spec behavior is undefined.
8. **Parallel access:** an uncommitted spec in one worktree is not shared with another worktree.
9. **Concurrency:** multiple sessions can write one workspace, but there is no locking/append contract.
10. **Cleanup:** ignored workspace history has no agreed archive/export behavior.
11. **Skill parity:** Claude and Codex do not currently have the same skills, agents, hooks, or rules.
12. **Skill semantics:** current skills still reference the old documentation and thought-stream model.
13. **Promotion:** `grill-with-docs` can create durable docs directly, conflicting with explicit promotion gates.
14. **Security model:** the desired security-review model is not defined; the current security reviewer is Sonnet.
15. **Shipping:** `open-a-pr` and `ship` have not been selected as the single canonical shipping surface.

## Smallest decisions before implementation

1. **Depot boundary:** keep Depot operational-only for V1, or explicitly supersede the control-plane V1 spec and make Depot the semantic workspace owner.
2. **Workspace schema:** select the `MISSION.md`/`thoughts.md`/typed-history model or the existing Melting model; do not support both as active contracts.
3. **Exact mission contract:** define identity, frontmatter, state transitions, objective, scope, next action, blockers, and spec binding fields.
4. **Binding/drift contract:** define source-commit behavior, missing specs, changed specs, and explicit rebind behavior.
5. **Machine manifest:** define the universal core, project layer, optional area packs, Claude/Codex parity, hooks, and security model policy.
6. **Setup/cleanup:** define who runs setup, how it is invoked, and how important workspace context is preserved before removal.
7. **Promotion/shipping:** define the promotion command/review path and select one canonical shipping skill.

## Recommended revised workflow

Given the active Depot V1 specification, the safest near-term workflow is:

```text
1. Depot or Git creates the worktree only.
2. Project-owned setup runs explicitly.
3. A harness-owned workspace initializer creates .workspace/.
4. Claude/Codex orient themselves from the workspace and project contract.
5. Brainstorm, grill, research, and findings stay in workspace history.
6. A scoping step writes specs/<slug>.scoping.md.
7. write-plan writes specs/<slug>.md.
8. The spec is committed before parallel build worktrees are created.
9. Each worktree binds the same spec independently.
10. Build, TDD, diagnosis, review, security review, E2E, and verification run explicitly as appropriate.
11. Important findings are promoted before cleanup.
12. One explicit shipping skill opens the PR.
13. The workspace is marked complete and exported/promoted before worktree removal.
```

If the desired command names must specifically be `depot workspace init/orient/bind`, then Depot needs a new, explicit semantic-workspace specification that supersedes the current V1 boundary. That change should not be smuggled into the harness migration.

## Day-to-day experience

The intended experience is:

> I create a clean worktree, open Claude or Codex, ask it to orient itself, and work conversationally until the task becomes a committed spec. The builder executes that spec while the workspace keeps local reasoning, evidence, handoffs, and findings out of the repository. Verification and shipping are explicit. Only durable knowledge is promoted into project documentation.

## Primary sources reviewed

- `/Users/daviscohen/dev/agentic-engineering/HIGH-LEVEL-CONTEXT.md`
- `/Users/daviscohen/dev/agentic-engineering/specs/harness-standardization/plan/tasks.md`
- `/Users/daviscohen/dev/agentic-engineering/specs/harness-standardization/README.md`
- `/Users/daviscohen/dev/agentic-engineering/README.md`
- `/Users/daviscohen/dev/agentic-engineering/CLAUDE.md`
- `/Users/daviscohen/melting/code/melting-v2/docs/workspace.md`
- `/Users/daviscohen/melting/code/melting-v2/docs/agent-environment.md`
- `/Users/daviscohen/melting/code/melting-v2/specs/README.md`
- `/Users/daviscohen/dev/depot/specs/control-plane-v1/README.md`
- `/Users/daviscohen/dev/depot/CLAUDE.md`
- live Depot CLI/worktree implementation;
- live Claude/Codex machine configuration and relevant skills, agents, hooks, and provider files.
