# Documentation architecture for agent-operated codebases

**Date:** 2026-07-31  
**Status:** Second-phase research; recommendation for pilot, not an adopted harness change  
**Scope:** Documentation and context architecture only. No production code changed.

## Executive answer

Yes: durable documentation is necessary. The answer is not to choose between a small `AGENTS.md`
and historical/design documentation; it is to give each kind of knowledge one owner and a different
loading policy.

The key distinction is:

> **Truth/lifetime says where a claim belongs. Discovery/loading says when an agent should read it.**

Recommended direction: keep a short provider-neutral `AGENTS.md` as a map plus a few always-relevant
working agreements; keep current architecture and domain context in the existing committed
`agent_docs/` tree; keep durable decisions in an append-only ADR log; keep proposals and execution
state in task/workspace artifacts; keep local contracts and non-obvious rationale beside the code.

`AGENTS.md` should therefore point to docs and define discovery rules. It should not be only an
abstract routing policy, and it should not become the encyclopedia.

## What the repository currently gets right

- `agent_docs/README.md` already separates current-state context from ADR history.
- `agent_docs/architecture.md` is intended to be a map, not a manual.
- `agent_docs/adr/` already uses the right immutable/superseding lifecycle.
- `specs/README.md` distinguishes committed task handoff from gitignored worktree scratch.
- `docs/` is intentionally an author/research notebook rather than part of the adopted tree.
- The current audit correctly identifies duplicated lifecycle prose and the absence of a task-to-doc
  routing index.

The main correction is not “add more docs.” It is to make the boundaries explicit, remove duplicate
claims, and make discovery useful enough that agents do not need to search the whole repository.

## Findings from external guidance

1. **A root agent file is a table of contents, not an encyclopedia.** OpenAI reports that a large
   `AGENTS.md` crowds out task context, rots, and is hard to verify; its replacement is a short map
   pointing to a structured repository knowledge base with indexes, design docs, plans, and
   generated references. ([OpenAI harness engineering](https://openai.com/index/harness-engineering/))

2. **Instruction files are context, not enforcement.** Codex layers `AGENTS.md` files from project
   root toward the working directory and caps the combined project guidance at 32 KiB by default.
   Claude Code similarly loads root instructions eagerly and uses nested files, path-scoped rules,
   and skills for narrower context. Both make locality and brevity operational concerns.
   ([Codex `AGENTS.md` guide](https://developers.openai.com/codex/guides/agents-md),
   [Claude Code memory and rules](https://code.claude.com/docs/en/memory))

3. **ADRs are historical decision memory, not design manuals.** AWS and Microsoft recommend a
   consistent record containing context, decision, alternatives/trade-offs, consequences, and
   status; accepted decisions are append-only and a changed decision creates a new superseding
   record. Microsoft explicitly says supplemental design material may be linked, but the decision
   must stand alone. ([AWS ADR process](https://docs.aws.amazon.com/prescriptive-guidance/latest/architectural-decision-records/adr-process.html),
   [AWS best practices](https://docs.aws.amazon.com/prescriptive-guidance/latest/architectural-decision-records/best-practices.html),
   [Microsoft ADR guidance](https://learn.microsoft.com/en-us/azure/well-architected/architect-role/architecture-decision-record))

4. **Current architecture should be a set of useful views.** arc42 separates context, building
   blocks, runtime, deployment, cross-cutting concepts, decisions, quality, risks, and glossary;
   C4 recommends hierarchical maps and says teams need only the levels that add value. For this
   harness, that means a small current map with links to domain-specific views, not a giant model
   of every class. ([arc42 overview](https://arc42.org/overview),
   [C4 introduction](https://c4model.com/introduction), [C4 diagrams](https://c4model.com/diagrams))

5. **Inline documentation should carry information code cannot.** Google’s engineering guidance
   distinguishes purpose/usage/behavior documentation for interfaces from implementation comments
   that explain non-obvious constraints or why a viable alternative was rejected; obvious code
   should be made clearer instead of narrated. ([Google code-review guidance](https://google.github.io/eng-practices/review/reviewer/looking-for.html),
   [Google C++ comments guidance](https://google.github.io/styleguide/cppguide))

6. **Documentation alone does not preserve coherence.** OpenAI describes cross-links, freshness and
   ownership checks, doc-gardening, and mechanical architecture invariants. The practical rule is
   to encode cheap-to-check facts and boundaries in tests/linters, while keeping human judgment and
   historical rationale in docs.

These sources are guidance, not proof that one taxonomy wins. The current review’s pilot should
measure navigation and correctness rather than assume more or less prose is automatically better.

## The four knowledge lifetimes

| Lifetime / owner | Belongs here | Must not become | Update rule | Agent loading |
| --- | --- | --- | --- | --- |
| **Historical / ADR** | Significant choices, context, alternatives, trade-offs, consequences, status, supersession links | A current-state manual or implementation checklist | Accepted decision body is immutable; a changed decision creates a new ADR | Index/headings first; read the relevant record when a task touches its scope or challenges it |
| **Current architecture** | What exists now: boundaries, components, flows, interfaces, invariants, deployment shape, domain terms, code paths | A diary of how the team arrived there or a future-state proposal | Edit in the same change that makes it false; link to the ADR for “why” | Start from the map; load only the domain/view relevant to the task |
| **Task / workspace** | Intent, acceptance criteria, chosen approach, task-local decisions, open questions, experiments, progress, test output, handoff state | Permanent repository truth by default | Draft → ready → active → complete/abandoned; promote durable facts/decisions, then archive or remove scratch | Load the bound task/spec; do not preload unrelated tasks or old sessions |
| **Inline code** | Public API/module purpose, usage, pre/postconditions, invariants, edge cases, tricky local rationale | Cross-system architecture, product history, or review-thread explanations | Co-evolve with the code; delete comments that become obvious or false | Read with the code it explains; avoid duplicating it in architecture prose |

Two additional surfaces remain useful:

- **`README.md`:** human-facing orientation, product purpose, quickstart, and contribution entry
  points. It may link to `AGENTS.md`, but it is not the agent contract.
- **Generated/reference docs:** generated schema/API/dependency views or vendored reference material.
  Mark the source and regeneration command; never hand-edit generated output as if it were truth.

## Recommended minimal taxonomy

Keep the current names during the pilot to avoid a taxonomy migration. The target shape is:

```text
AGENTS.md                         # short map + always-relevant contract
CLAUDE.md                         # Claude adapter; imports AGENTS.md, adds only Claude-specific rules
README.md                         # human onboarding
agent_docs/
  README.md                       # agent-facing index and task-to-doc routing table
  architecture.md                 # current system map and invariants
  glossary.md                     # domain language
  domains/<area>.md               # optional current-state views, only when needed
  adr/
    README.md                     # ADR format/lifecycle/index
    NNNN-slug.md                  # one significant decision per file
  design/<slug>.md                # optional active proposals; never silently treated as current
specs/
  README.md                       # task artifact lifecycle
  <task>.md                       # committed plan/handoff when needed
  .context/<task>.md              # gitignored worktree scratch
docs/                             # harness-author research and rationale; not agent startup context
```

### What goes in `AGENTS.md`

Keep it roughly 60–120 lines, with only stable, broad, verifiable material:

- one-paragraph repository identity and the top-level map;
- the real setup, test, lint, and quality-gate commands;
- a few hard constraints that apply to every task;
- the documentation contract: “current state lives in `agent_docs/`; history lives in `adr/`; task
  state lives in `specs/`/workspace scratch; when in doubt, use the index”;
- a routing table such as “understand system shape → `agent_docs/architecture.md`; domain X →
  `agent_docs/domains/x.md`; why decision Y → ADR index/search; active task → bound spec”;
- provider-neutral facts only. Provider-specific hooks, permissions, skill syntax, and subagent
  configuration stay in adapters.

Do not put the full architecture, ADR contents, long procedures, historical narrative, or generic
coding advice in this file. A pointer that names the next file and the condition for opening it is
more useful than a pointer to an undifferentiated `docs/` directory.

### Indexing and discovery rules

`agent_docs/README.md` should become a real index, not only a directory description. Each entry
should state:

```text
doc | kind | status | scope/path | read when | source of truth | verified by
```

Use predictable filenames and links, plus optional frontmatter for machine checks:

```yaml
kind: architecture | adr | design | glossary | generated
status: current | proposed | accepted | superseded | historical
scope: paths, services, or domains affected
source_paths: [src/..., config/...]
verify: command or review check
owner: team or role
```

The index should route by task shape, not only by folder:

- “Where does this behavior live?” → architecture map, then the matching domain view.
- “What contract must I preserve?” → architecture invariant, interface docs, tests, and relevant ADRs.
- “Why is it built this way?” → ADR index, then only the records linked to the affected area.
- “What is planned or in progress?” → bound spec/design doc; never infer future state from current docs.
- “What procedure should I follow?” → provider skill/rule, not a current architecture document.

Nested `AGENTS.md` files are warranted only at real repository/package boundaries. They should route
to local docs and commands, not repeat the root contract.

## Four documentation architectures

### A. Flat canonical set — lowest change

Use one short `AGENTS.md`, one current `agent_docs/architecture.md`, one glossary, one ADR directory,
and `specs/` for tasks. No domain sub-index until the repository needs it.

**Benefits:** smallest migration and maintenance surface; easy to explain; good for a small repo.  
**Costs:** the architecture map can become a bottleneck; task routing gets vague as the repo grows.  
**Best fit:** the current harness itself while it is mostly scaffolding.

### B. Indexed progressive-disclosure knowledge base — recommended

Keep the same core set, add a real index with status/scope/read-when metadata, split current
architecture by domain only when justified, and link each doc to code paths, tests, ADRs, and active
designs. Provider files are thin adapters to the same map.

**Benefits:** preserves historical docs, supports targeted loading, scales to monorepos, and makes
  freshness/ownership/link checks possible.  
**Costs:** requires disciplined indexing and a small amount of metadata; an index can itself drift.  
**Best fit:** this harness and codebases operated by multiple agent providers.

### C. Code-derived / mechanically validated architecture

Treat the code, schemas, dependency graph, and tests as primary facts; generate or validate selected
architecture views and indexes from them. Keep ADRs and design docs human-authored, but require
source-path links and structural checks for current docs.

**Benefits:** strongest stale-doc resistance for paths, dependencies, contracts, and generated views;
  good for high-throughput agent development.  
**Costs:** tooling investment; generated views can be precise but architecturally unhelpful; cannot
  derive rationale or intent reliably from code.  
**Best fit:** a later pilot extension, not the first migration.

### D. Orchestrator-owned knowledge base

Store most task context and routing outside the repository; the repo carries only a small map and
provider adapters, while an orchestrator assembles context packs for each run.

**Benefits:** centralized observability, provider routing, resumability, and task-specific loading.  
**Costs:** local runs become second-class; repository history becomes incomplete; external state is
  unavailable to offline/forked agents; the orchestrator becomes a source-of-truth dependency.  
**Best fit:** specialized enterprise orchestration, not the portable base contract.

**Recommendation:** adopt B, implement only the low-cost parts of C as checks, and keep D out of the
repository contract. Use A as the immediate transitional shape if the index work is not yet funded.

## What to merge, demote, or delete

Do not delete ADRs or historical research merely because agents can inspect code. Delete or merge
duplicate *claims* and stale navigational surfaces:

1. **Make one owner for each lifecycle contract.** Keep `specs/README.md` as the operational spec
   lifecycle and keep `docs/PLAN-MODE.md` as optional rationale, but remove repeated step-by-step
   lifecycle text from `README.md`, `CLAUDE.md`, `.claude/FLOOR.md`, and skills. Those surfaces should
   point to the owner or state only the invariant they enforce.
2. **Make current architecture single-sourced.** Put current system shape, domain terms, and
   invariants in `agent_docs/`; remove duplicated architecture facts from provider floors and human
   narrative docs. Keep a tiny map/pointer in `AGENTS.md`.
3. **Keep `docs/` out of the adopted agent context.** `docs/SOURCES.md`, `docs/recommended/*`, and
   `docs/ARCHITECTURE-REVIEW-2026-07.md` are valuable harness-author history/catalogs, but they are
   not runtime repository truth for an adopting codebase. Mark them as research/reference and stop
   using them as operational sources.
4. **Retire stale catalogs.** The current audit already found that the skill catalog omits newer
   skills. Either generate inventory tables or make the catalog explicitly non-authoritative; do not
   maintain a second hand-written roster that agents may mistake for the live tree.
5. **Do not merge ADRs into current architecture.** Keep the separate lifecycle. The architecture
   map should link to relevant ADRs; an ADR should link back to affected current views and code.
6. **Do not turn completed specs into permanent architecture by default.** Keep them only when they
   are useful project history or contain a durable decision; promote that decision to an ADR/current
   doc, then archive or remove the task artifact according to repository policy.

## Lifecycle and freshness rules

1. **One claim, one owner.** Every operational fact has one canonical file. Other files link to it
   and may summarize only if the summary is deliberately lossy and still points to the owner.
2. **Current-state docs are edited, not appended.** If a code change makes a map, command, path,
   contract, or invariant false, update the current doc in the same change. Include `source_paths`
   and a verification command or test where practical.
3. **ADRs preserve history.** Use `proposed → accepted → superseded/rejected`; accepted decision
   content is immutable. A new decision carries the new context/trade-offs and links both ways.
4. **Design docs are explicitly transitional.** Use `draft → accepted → implementing → implemented`
   or `superseded`. An accepted design is not current architecture until implementation is verified.
   On implementation, update current docs and link the design/ADR; do not leave two “current” versions.
5. **Specs are task state, not repository law.** A spec may resolve a task-local decision and link
   durable records. On completion, mark it complete, promote durable material, and archive/delete
   the rest. Gitignored scratch is never a source of truth.
6. **Inline docs co-evolve with code.** Document public usage and non-obvious local constraints near
   the symbol. Move cross-component rationale to an ADR and broad behavior to current architecture.
7. **Generated docs declare their source.** Record the generator and command; CI should regenerate or
   compare output rather than trusting a hand-edited snapshot.
8. **Freshness is evidence-based.** Check dead links, missing paths/commands, invalid status links,
   source-path coverage, and selected architecture invariants. “Last updated” alone is not freshness.
9. **Garbage collection is normal.** Run a report-only docs-drift pass on a cadence or after broad
   structural changes; remove duplicate, superseded, or unused docs when there is a clear owner.
10. **No aspirational language in current docs.** “Will,” “planned,” and “proposal” belong in a
    design/spec artifact with an explicit status, not in a document labeled current architecture.

## Small pilot and evaluation plan

Pilot the recommended taxonomy before changing the harness broadly.

### Variants

1. **Baseline:** current `CLAUDE.md`/floor plus existing `agent_docs/` and specs.
2. **Lean map:** short provider-neutral `AGENTS.md`/adapter, with duplicated workflow prose removed;
   current architecture and ADRs unchanged.
3. **Indexed map:** lean map plus the task-to-doc index, status/scope metadata, and one or two
   domain views; use only the relevant view per task.
4. **Indexed + checks:** variant 3 plus dead-link/path checks and one architecture/navigation probe.

### Tasks

Use 8–10 matched tasks across two repositories and, if available, two providers:

- simple local bug fix;
- new feature crossing two modules;
- change to a documented public contract;
- task requiring an ADR lookup;
- task touching a risk hotspot;
- unfamiliar-domain investigation;
- continuation from a fresh session/worktree;
- task where an architecture doc is intentionally stale;
- optional design-proposal task and docs-only task.

Keep starting commit, prompt, model/settings, worktree setup, and acceptance tests as constant as
practical. Have each run report the instruction/docs it loaded and the first relevant file it found.

### Measures and success signals

- **Navigation:** time/tool calls to first relevant file; relevant versus irrelevant files read;
  whether the agent found the right doc without a human hint.
- **Correctness:** tests, acceptance criteria, reviewer findings, and violations of documented
  invariants or contracts.
- **Continuity:** fresh session can resume from committed task state plus the worktree pointer.
- **Cost:** tokens, wall-clock time, context compactions, and human corrections.
- **Maintenance:** duplicate claims, broken links, stale-path findings, and minutes needed to update
  docs after a structural change.

Adopt the indexed model only if it reduces irrelevant exploration or human correction without
reducing correctness. Keep a doc only when it is discoverable, non-redundant, and tied to an observed
failure or a durable need. The pilot should not optimize for the number of files or lines of docs.

## Decision requested after the pilot

The next implementation decision is narrow:

1. create the short provider-neutral `AGENTS.md` contract and thin provider adapter;
2. make `agent_docs/README.md` a task-routed index;
3. classify existing docs by lifetime/status and remove duplicate lifecycle prose;
4. add only report-only link/path/index checks;
5. run the pilot and decide whether generated architecture checks earn their maintenance cost.

Do not start by rewriting every document or adding a general documentation platform.

## Sources

- [OpenAI — Harness engineering](https://openai.com/index/harness-engineering/)
- [OpenAI — Codex `AGENTS.md` guide](https://developers.openai.com/codex/guides/agents-md)
- [Anthropic — Claude Code memory, rules, and skills](https://code.claude.com/docs/en/memory)
- [Agentic AI Foundation — `AGENTS.md`](https://agents.md/)
- [AWS — ADR process](https://docs.aws.amazon.com/prescriptive-guidance/latest/architectural-decision-records/adr-process.html)
- [AWS — ADR best practices](https://docs.aws.amazon.com/prescriptive-guidance/latest/architectural-decision-records/best-practices.html)
- [Microsoft — Maintain an ADR](https://learn.microsoft.com/en-us/azure/well-architected/architect-role/architecture-decision-record)
- [arc42 — template overview](https://arc42.org/overview)
- [C4 model — introduction and diagrams](https://c4model.com/introduction)
- [Google — code review: what to look for](https://google.github.io/eng-practices/review/reviewer/looking-for.html)
- [Google — C++ comments guidance](https://google.github.io/styleguide/cppguide)
