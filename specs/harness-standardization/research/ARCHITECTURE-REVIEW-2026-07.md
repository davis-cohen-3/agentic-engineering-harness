# Agentic harness architecture review

**Date:** 2026-07-31  
**Status:** Initial audit and research; provisional recommendation, not an adopted design  
**Scope:** The harness repository and its portable workflow boundary. No Melting code was changed.

## Executive finding

The harness has the right instincts—progressive disclosure, a small set of read-only reviewers,
deterministic gates, isolated worktrees, and repository-local context—but its current instruction
system is more layered and provider-specific than its single-source discipline suggests.

The largest issue is not that it has too little documentation. It is that the same workflow claims
are repeated across `README.md`, `CLAUDE.md`, `.claude/FLOOR.md`, `specs/README.md`, `docs/PLAN-MODE.md`,
and the skills, while Codex does not natively load `CLAUDE.md` and the repository has no
provider-neutral instruction entrypoint. The result is a system that is conceptually coherent for
Claude Code, but not yet a portable worktree/workspace contract for Codex, Claude Code, or a future
provider.

The working hypothesis for the next phase is:

> Keep a small, provider-neutral task contract and repository map; load procedures on demand;
> enforce only high-cost invariants mechanically; measure whether each instruction improves the
> agent's behavior before making it permanent.

This is a hypothesis to pilot, not a conclusion that all guidance is harmful.

## 1. What currently governs an agent

### Current surfaces

| Surface | Current role | Loading / enforcement reality | Audit note |
| --- | --- | --- | --- |
| `CLAUDE.md` + `.claude/FLOOR.md` | Profile plus inherited “always-on” floor | Claude Code loads them; the `@` import expands the floor into the startup context | 64 + 56 lines before skills, rules, tools, or task context; both restate the mode, gate, risk, and documentation model |
| `.claude/rules/` | Path-scoped conventions | Claude Code loads matching rules on demand; unscoped rules are always-on | Good mechanism; only two examples exist, and the project-specific rules are still Claude-specific |
| `.claude/skills/` | Procedures and repeatable workflows | Claude Code discovers descriptions and loads bodies when invoked/relevant; `SKILL.md` is portable in principle | Strongest cross-provider asset; several skills contain vendor-specific triggers, markers, or assumptions |
| `.claude/agents/` | Scout/research/review isolation | Claude Code subagent configuration | Useful roles, but provider/model/tool frontmatter is not portable |
| `.claude/hooks/` + `settings.json` | Guardrails, stop gate, orientation, nudges | Claude Code lifecycle hooks only | Enforcement is valuable, but cannot be the only safety layer across providers; some hooks fail open |
| `specs/` | Task-local plan, decisions, sessions, scratch | Repository files; session hook injects the active spec for Claude Code | Good lifetime separation; lifecycle is described in at least four other places |
| `agent_docs/` | Repository map, glossary, ADR history | Intended load-on-demand reference | Good progressive-disclosure shape, but the harness itself only has placeholders and no indexed task-to-doc routing |
| `Makefile` + `make/gate.mk` | Setup and one named quality gate | Shell/make, provider-neutral | Useful boundary; base gate is intentionally a no-op when unconfigured, so “green” can mean “no real checks” |
| `docs/` | Author notebook and recommendation catalog | Not intended to travel | Correct separation in principle; it is still referenced heavily enough to shape the mental model of the base |
| `.mcp.json` | Optional tool/server declarations | Claude Code-oriented configuration | Empty by default is sensible; no provider-neutral capability declaration exists |

### Effective hierarchy observed

1. The repo profile imports the floor, making the floor always-on rather than merely discoverable.
2. The floor establishes definition of done, plan/build modes, task tiers, risk hotspots, and skill
   markers.
3. Skills then repeat the mode boundaries and tell agents when to invoke one another.
4. Specs repeat the same plan/build and context-lifetime model, while hooks re-inject parts of it.
5. The gate and hooks enforce only a subset of what the prose calls mandatory.
6. The whole chain is optimized for Claude Code. Codex's documented discovery chain is
   `AGENTS.override.md` / `AGENTS.md` by directory, with a default 32 KiB combined limit; this repo
   has neither file. A Codex run therefore will not see this profile unless an external fallback or
   prompt adapter is configured.

## 2. What is working

- The `agent_docs/README.md` distinction between a small index, current-state maps, and durable ADR
  history is a sound information-lifetime model.
- The spec split between committed task artifacts and gitignored worktree scratch is useful. The
  `.claude/active-spec` pointer is a practical worktree-local binding mechanism.
- `scout` and `researcher` isolate read-heavy exploration from the builder; `reviewer` and
  `reviewer-security` provide a separate fresh-eyes pass. This is a better boundary than a swarm of
  overlapping specialists.
- The quality gate is named once at the command boundary, and the overlay enumerates custom checks
  instead of pretending the base can discover architecture-specific validation.
- The hooks target silent or expensive failures: default-branch writes, destructive shell, secrets,
  failed gates, and context loss after compaction.
- The manifest in `copy.sh` makes the portable boundary explicit and prevents the author's `docs/`
  notebook from travelling into adopted repositories.

## 3. Problems and concrete risks

### A. “Single source” is asserted but the lifecycle is multi-sourced

The same concepts are independently narrated in:

- plan/build modes: `README.md`, `.claude/FLOOR.md`, `docs/PLAN-MODE.md`, `specs/README.md`, and
  `brainstorm`, `write-plan`, and `adopt-harness`;
- definition of done: `.claude/FLOOR.md`, `README.md`, `Makefile`, `verify-before-done`, `reviewer`,
  and `open-a-pr`;
- context lifetimes: `agent_docs/README.md`, `specs/README.md`, `specs.md`, the session hook, and
  `handoff`;
- risk escalation: `CLAUDE.md`, `.claude/FLOOR.md`, `CLAUDE.template.md`, the spec template, and
  both reviewers.

The links reduce literal duplication, but they do not make the behavioral contract single-sourced:
an agent can encounter several descriptions, scopes, and exceptions. This is the likely source of
noise and future drift.

There is also concrete inventory drift: the README and recommendation catalog describe the older
skill roster but omit the later `docs-drift` and `overview-fresh` skills. The active repository has
11 skill directories. A catalog that is itself stale undermines the navigation contract it is meant
to provide.

### B. Provider portability is currently a claim, not a capability

The README calls the artifact a “portable Claude Code harness.” That is honest, but it conflicts
with the stated future of Codex + Claude Code + more providers. `CLAUDE.md`, `.claude/settings.json`,
hooks, subagent frontmatter, `@` imports, skill markers, and the global `install-global` target all
depend on Claude Code behavior. There is no canonical provider-neutral task manifest, context map,
or adapter contract.

The portable unit should therefore be defined by semantics (task contract, repository map, gate,
risk declarations, handoff state), with Claude/Codex/provider files treated as adapters. A file being
Markdown does not by itself make its loading or enforcement portable.

### C. Some “always-on” rules are workflow preferences, not repository invariants

The floor includes skill-marker replies, mandatory two-mode behavior, “ship via PR,” task tiers,
collaboration posture, and a rule that a run never splits across sub-agents. Some are useful for the
current operator or orchestrator, but they do not all belong in every repository's startup context.
They consume attention and can conflict with a provider's native worktree, review, or delegation
model. The portable floor should be reserved for invariants that are broadly true, expensive to
violate, and either mechanically enforced or directly testable.

### D. Enforcement is uneven and sometimes fail-open

- `make check` passes in this harness, but it only validates JSON and hook executable bits. The base
  Makefile intentionally treats an absent overlay as a successful no-op, so a green result is not
  evidence of application correctness.
- `enforce-gate-on-stop.sh` has a circuit breaker, but does not implement the `stop_hook_active`
  recursion guard that `docs/recommended/hooks.md` itself calls out as required for Stop hooks.
- Security hooks bypass protection when `jq` is missing. This is a defensible availability tradeoff,
  but it is not equivalent to a safety guarantee and should be labeled as such.
- `copy.sh` is deliberately “idempotent-ish,” but recursive copying can overwrite filled files on a
  re-run. The warning is useful; a dry-run or versioned migration boundary would be safer.
- The four configured agents all retain `Bash` even when their descriptions say read-only. “No
  `Write` tool” is therefore a prompt-level convention, not a technical write boundary.
- The README presents reviewers as part of build mode, but no local hook, command, or script invokes
  them. That may be supplied by Warren, but it is an external integration claim and should not be
  presented as a property of the repository without an adapter or conformance check.
- `make install-global` intentionally syncs only Claude skills, agents, and commands; rules and hooks
  remain split between global and project scopes. That is a reasonable safety choice, but it makes
  provider/config drift an expected operating condition rather than an exceptional failure.

### E. The worktree boundary is present, but the workspace boundary is absent

The repository models a task branch/worktree and a burrow clone, but not the user's actual
worktree→workspace abstraction: what a workspace owns, how a provider attaches to it, how a task is
resumed or handed off, what state is committed versus local, and how provider-specific capabilities
map onto the same task. Without that contract, “provider support” will likely become a collection of
ad hoc launch instructions.

The audit found no provider/worktree creator, CI workflow, Warren/Burrow adapter, or orchestration
implementation in this repository; `.conductor/` is empty and `.mcp.json` is intentionally empty.
That is a useful scope boundary, but it means the current docs describe integrations that are not
represented or tested here.

### F. Documentation maintenance is described more strongly than it is measured

`docs-drift` and `overview-fresh` are useful hygiene ideas, but the current harness has no general
documentation index validator, source-of-truth checker, or agent-behavior evaluation. The docs say
“keep it current” and “prefer progressive disclosure,” but do not currently test whether an agent
finds the right context, follows a convention, or avoids irrelevant reads.

## 4. External evidence (and what it does not prove)

### Strong signals

1. **Both major providers now support layered, scoped instructions.** Codex documents global plus
   root-to-working-directory `AGENTS.md` chains, one file per directory, with a 32 KiB default cap;
   Claude Code documents root-to-working-directory `CLAUDE.md` loading, path-scoped rules, and skills
   that load on demand. This supports a small root contract plus scoped depth, not one universal
   manual.  
   Sources: [Codex AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md),
   [Claude Code memory](https://code.claude.com/docs/en/memory),
   [Claude Code skills](https://code.claude.com/docs/en/slash-commands).

   The emerging cross-provider convention is `AGENTS.md`: Claude Code can import it from
   `CLAUDE.md`, while Codex loads it natively. GitHub Copilot also documents support for several
   instruction filenames, but does not promise a single precedence order across all classes; this
   is further evidence to avoid conflicting parallel sources.  
   Sources: [AGENTS.md](https://agents.md/),
   [Copilot custom instructions](https://docs.github.com/en/copilot/reference/custom-instructions-support).

2. **Repository-local knowledge is valuable when it is organized and enforceable.** OpenAI's
   harness-engineering report describes a small map, repository knowledge as the system of record,
   progressive disclosure, executable plans, and mechanical architecture/quality checks. It also
   explicitly reports that documentation alone does not preserve coherence.  
   Source: [Harness engineering](https://openai.com/index/harness-engineering/).

3. **Worktrees are a natural isolation boundary, not an implementation detail.** Git documents
   linked worktrees as independent checkouts sharing repository metadata; Codex's desktop docs use
   them to run parallel chats without interference and to hand work between local and background
   contexts. This supports making the worktree/workspace contract explicit in the portable design.
   Sources: [git-worktree](https://git-scm.com/docs/git-worktree.html),
   [Codex worktrees](https://learn.chatgpt.com/docs/environments/git-worktrees).

4. **Skills are the clearest current cross-provider seam.** The Agent Skills open standard uses a
   `SKILL.md` entrypoint plus optional scripts/references/assets and progressive disclosure; Anthropic
   and OpenAI both describe the format as portable/open. This does not make hooks, agents, or
   permissions portable, but it gives the harness a provider-neutral procedural unit to build on.
   Sources: [Agent Skills](https://agentskills.io/home),
   [Anthropic Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills),
   [OpenAI Using skills](https://openai.com/academy/skills/).

5. **Multi-agent orchestration should be selective.** Anthropic's current architecture guide says
   multi-agent systems fit open-ended, multi-domain, or independently parallelizable work, but carry
   proportional token, coordination, and observability costs; simple tasks should not trigger them.
   This supports the current small roster, but argues for explicit escalation criteria rather than a
   mandatory planner/builder/reviewer ceremony for every change.  
   Source: [Building Effective AI Agents](https://resources.anthropic.com/hubfs/Building%20Effective%20AI%20Agents-%20Architecture%20Patterns%20and%20Implementation%20Frameworks.pdf), especially pp. 13, 19, and 22–24.

### Conflicting or preliminary evidence

Recent preprints disagree on the net effect of repository context files:

- one 10-repository/124-PR study reports lower median runtime and output tokens with `AGENTS.md`,
  with comparable task completion;
- a 12-repository/138-instance study reports that context files can increase exploration and cost
  without improving success, and concludes that human-written files should contain only requirements
  not already present elsewhere;
- a 288-run Claude Code/Codex ablation reports no measurable correctness change within its study
  bounds, while a probe-and-refine study reports gains when guidance is tuned against concrete probes.

These are not a license to delete context. They support an evaluation rule: keep a guidance item only
when it is human-validated, non-redundant, and tied to an observable behavior or failure mode.
Sources: [efficiency study](https://arxiv.org/abs/2601.20404),
[CTXbench](https://arxiv.org/abs/2602.11988),
[two-agent ablation](https://arxiv.org/abs/2607.27250),
[probe-and-refine](https://arxiv.org/abs/2606.20512). These are early research and should be
treated as directional, not as production benchmarks.

## 5. Architecture options

### Option A — Portable contract + provider adapters (provisional recommendation)

Define a small provider-neutral repository contract: task intent/acceptance, context map, setup and
quality commands, risk declarations, handoff state, and worktree/workspace identity. Keep one concise
root entrypoint in a neutral filename, with provider adapters that point to or project it into
`AGENTS.md`, `CLAUDE.md`, or another native format. Keep skills as the main portable procedure unit;
keep hooks, permissions, subagents, and MCP declarations in adapters.

**Good at:** Codex + Claude Code today, future providers, shared worktrees, gradual migration.  
**Costs:** Requires a small schema/adapter convention and some deliberate duplication at the
provider edge.  
**Removes/weaken:** the universal floor, skill markers, repeated lifecycle prose, and assumptions
that a provider's hook/agent model is the workflow itself.

The adapter boundary should be explicit: shared Markdown and command semantics are portable;
provider-specific permissions, hooks, subagent definitions, MCP configuration, model selection, and
context loading are not. Safety-critical behavior must have a provider-neutral fallback such as CI,
the quality gate, or the worktree/branch contract.

### Option B — Claude-native harness, with Codex as a documented exception

Keep the existing `.claude/` tree and improve its internal source-of-truth discipline. Add a thin
Codex `AGENTS.md` adapter only when a Codex task is launched.

**Good at:** lowest immediate change; preserves mature Claude behavior.  
**Costs:** Codex and future providers remain second-class; adapters can drift; the worktree/workspace
contract stays implicit.  
**Removes/weaken:** repeated Claude prose and low-value always-on rules, but does not solve the
semantic portability problem.

### Option C — Orchestrator-first task runtime

Make the worktree/workspace orchestrator the source of task state and provider routing. Repositories
carry only a small codebase map, gate, and safety declaration; the orchestrator supplies the plan,
context, skills, and handoff envelope to each provider.

**Good at:** heterogeneous providers, resumability, explicit workspace lifecycle, centralized
observability.  
**Costs:** agents lose useful context when launched outside the orchestrator; the orchestrator becomes
a large, high-coupling control plane; local Claude/Codex sessions are less faithful to cloud runs.
**Removes/weaken:** most repo-local workflow prose and provider config, but risks moving architecture
knowledge out of the repository—the failure mode the harness is trying to avoid.

### Option D — Repository-as-system-of-record + mechanical knowledge quality

Keep rich repository-local maps, decision logs, plans, and provider adapters, then add structural
linters, docs indexes, stale-reference checks, and task probes that grade navigability and architecture
invariants continuously.

**Good at:** high autonomy, long-lived codebases, measurable legibility and entropy control.  
**Costs:** highest investment and maintenance; can encode the wrong architecture more efficiently;
requires a recurring garbage-collection loop.  
**Removes/weaken:** less prose enforcement in favor of executable checks, but does not by itself
solve cross-provider loading.

## 6. Decision tree for the next design conversation

1. **Is Codex + Claude Code + future providers a hard requirement?**
   - **Yes:** start from Option A. Option B is only a temporary bridge.
   - **No:** Option B is a reasonable short-term cleanup, with a portability seam kept explicit.
2. **Must an agent be able to resume from a worktree without the original chat/orchestrator?**
   - **Yes:** task state and handoff must be repository-local; reject a pure Option C.
   - **No:** Option C becomes viable for more of the lifecycle.
3. **Is autonomous throughput high enough that architecture drift is the dominant cost?**
   - **Yes:** add the smallest Option D pilot: one structural invariant and one context/navigation probe.
   - **No:** do not build a broad evaluator platform yet.
4. **Are hooks available and trustworthy in every target provider?**
   - **No:** move safety semantics to commands/CI/task contracts and treat hooks as optional acceleration.
   - **Yes:** retain provider hooks, but test their failure mode and keep a provider-neutral fallback.

## 7. Gradual path (no implementation decision implied)

### Immediate cleanup to discuss

- Inventory every always-on paragraph and classify it as **invariant**, **procedure**, **repo fact**,
  or **personal/orchestrator preference**.
- Choose one canonical home per semantic claim; replace other copies with short pointers or remove
  them. Start with plan/build lifecycle, definition of done, context lifetimes, and risk handling.
- Define the worktree/workspace boundary in provider-neutral terms before adding another provider.
- Make the base gate's unconfigured state explicit and non-confusable with a real passing gate.
- Audit hook contracts against the current provider docs, especially Stop recursion, fail-open behavior,
  and whether every claimed guardrail is actually wired.

### Small pilot

Use 6–10 representative tasks across two repositories and two providers:

1. baseline: current instructions and current provider-native launch;
2. lean: a short neutral task contract plus the existing repository map, with redundant floor prose
   removed from the provider projection;
3. lean + one scoped skill or rule when the task requires it.

Keep task prompts, starting commits, model settings, and worktree setup as constant as practical.
Have the agent report loaded instruction sources, relevant files found, checks run, and handoff state.
Do not use completion alone as the metric: record correctness, irrelevant reads, tool calls/tokens,
time-to-first-relevant-file, gate/verification failures, and human correction cost.

### Evaluation criteria

- **Correctness:** acceptance tests and reviewer findings.
- **Navigation:** time/tool calls to the first relevant file; irrelevant files read; whether the
  agent found the documented pattern without being spoon-fed.
- **Instruction adherence:** required checks actually run; risky changes escalated; no invented
  design decisions when a spec is incomplete.
- **Portability:** same task contract works in both providers; provider-specific adapters are the
  only differences.
- **Continuity:** a fresh session can resume from the worktree using committed state plus the local
  handoff pointer.
- **Cost/friction:** tokens, wall-clock time, number of turns, and human interventions.
- **Maintenance:** stale links, duplicate claims, and changes needed after a provider update.

## 8. Open questions and rejected defaults

### Open questions for the next session

- What is the smallest provider-neutral artifact: a single `AGENTS.md`, a task manifest plus map, or
  a conventional directory with a generated provider projection?
- Which parts of the user's workspace abstraction are durable state versus provider runtime state?
- Is “one run builds one task” a safety invariant, an orchestrator optimization, or merely a current
  preference?
- Should an unconfigured `make check` fail, warn-and-pass, or be replaced by an explicit `make
  bootstrap`/`make verify` contract?
- Which provider behaviors can be tested in a shared conformance suite rather than documented?

### Rejected for now

- **Add more always-on guidance** before measuring the current guidance. The evidence does not justify
  increasing the token tax by default.
- **Build a general multi-agent swarm** into the harness. The current roles are enough for a pilot;
  orchestration complexity should be earned by a demonstrated need.
- **Move all architecture knowledge into the orchestrator.** That would make local and future
  provider runs less legible and create an external source-of-truth dependency.
- **Treat ADR volume as context quality.** Durable history is useful, but an append-only log is not a
  navigation strategy; the current-state map and task routing matter more.

## Next-session entry point

Start by choosing Option A, B, C, or D against the decision tree above. Then define the minimum
provider-neutral contract and write a 6–10-task pilot matrix before changing the harness. The next
implementation conversation should begin with this file, the user's worktree/workspace abstraction,
and one real Melting task as a read-only case study—not with another broad rewrite of the floor.
