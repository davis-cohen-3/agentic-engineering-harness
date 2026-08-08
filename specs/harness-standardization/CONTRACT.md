# Harness + Depot Operating Contract

**Status:** Reconciled against all settled decisions. Not yet implemented — nothing here has been built.
**Settled:** 2026-08-07 (DEC-1…15) and 2026-08-08 (A–J), across two decision passes and two audits.
**Authority:** [`DECISIONS-PENDING.md`](./DECISIONS-PENDING.md) outranks this document; this document
outranks [`docs/HARNESS-DEPOT-OPERATIONAL-DESIGN-REVIEW.md`](../../docs/HARNESS-DEPOT-OPERATIONAL-DESIGN-REVIEW.md),
which outranks `plan/tasks.md`. `PRE-IMPLEMENTATION-CONTRACT-AUDIT.md` and `01-*.md`…`08-*.md` are
historical and not executable.

This is the self-contained statement of the operating model. Verified machine facts and the
reasoning behind each choice live in the decisions file; this document states what is true.

---

## 1. The model

```text
harness repo            core/ + adopt/       the versioned source
  ↓ install.sh
machine core            ~/.agents/           an installed projection, never edited in place
  ↓
provider entry points   ~/.claude/  ~/.codex/    runtime state + thin adapter
  ↓
project harness         AGENTS.md, CLAUDE.md, docs/, specs/, .claude/, .codex/, .agents/skills
  ↓
Git worktree            one checkout, one task branch
  ├── committed         code, tests, docs/, specs/
  └── untracked         .workspace/    task memory, dies with the worktree
```

Four owners, no overlap:

| Owner | Owns |
| --- | --- |
| **Depot** | git worktrees it created, tmux sessions, dev apps, files/diffs, phone access, guarded removal |
| **The harness** | `.workspace/`, skills, agents, hooks, the portable contract |
| **The project** | setup, dependencies, quality gate, PR review bot if any, domain guidance |
| **You** | promotion decisions, review, shipping, anything irreversible |

**Depot never creates, writes, validates, repairs, or interprets `.workspace/`.** It may render it
read-only. This is Depot's shipped, accepted position (`agent_docs/adr/0004`,
`specs/control-plane-v1/`); the harness documents described a boundary that had never been built.

---

## 2. `.workspace/` — per-worktree task memory

```text
.workspace/
  MISSION.md                            where we are now; overwritten
  LOG.md                                ordered DECISION / QUESTION entries; appended
  history/
    YYYYMMDDTHHMMSSZ-<type>-<slug>.md   type ∈ {handoff, finding}
  artifacts/                            large raw evidence, linked from a history record
```

Untracked, per-worktree, shared by every session in that worktree, disposable. Excluded via the
**global gitignore** (`~/.config/git/ignore`) — no repository `.gitignore` mentions it.

Directories are created on demand. No `README.md` inside it, no schema validation, no repair, no
"malformed workspace" concept.

| Surface | Mutability | Holds |
| --- | --- | --- |
| `MISSION.md` | overwritten | the current position |
| `LOG.md` | append-ordered | settled decisions and still-open questions |
| `history/` | append-only, immutable | the two things another session must find |
| `artifacts/` | **write-once** | raw evidence a history record points at |

### `MISSION.md`

```markdown
---
state: scoping        # scoping | building | shipped | abandoned
spec: null            # or specs/<slug>.md
---

# Mission

## Objective
## Current position
## Next action
## Blockers
```

Two frontmatter fields, both defaulted. An agent that writes nothing but prose under the four
headings has used it correctly.

**Deliberately absent:** `workspace_id` (nothing consumes one — Depot removed the field entirely);
`project` / `worktree` / `branch` (derivable from git, and they go stale on rename); `Scope` and
`Constraints` (they live in `LOG.md` before a spec exists and in the spec after); a `verified` state
(verification is a gate, not a state); a `blocked` state (duplicates Blockers and can disagree).

**Two obligations, each with an owner.** Not two *moments* — creation and transitions fall outside
them:

| Write | Owner |
| --- | --- |
| Create the file | `ensure-workspace.sh` / `WorktreeCreate` — not an agent write |
| `state: building` + `spec:` | **`write-plan`**, as it writes the spec |
| `spec:` in a T3 **build** worktree | **the developer or the first session**, at step 6 of §7 — `write-plan` does not run there |
| Sync before a history record | **`handoff`**, immediately before writing it |
| Final position, `state: shipped` | **`/ship`** or an explicit close |
| `state: abandoned` | explicit close only |
| After an abrupt end | nothing — staleness is accepted |

The third row exists because `write-plan` runs once, in the *planning* worktree, and sets that
worktree's mission. The N build worktrees cut afterwards each need their own `spec:` set, and no
skill runs there to do it. It is a one-line manual edit, and it is the only `MISSION.md` write with
no automated owner.

The rule is this small because the expensive part of an update obligation is not the write, it is
the ambient monitoring needed to notice a boundary. Every obligation rides an action the agent
already deliberately chose to take, so detection costs nothing. **A session grinding through one
task touches `MISSION.md` zero times.**

There is no "at session end" obligation: a provider's SessionEnd hook can fire after the model can
no longer act. A session that dies leaves a stale mission; the recovering session reads
`git status`, `git log`, and the tail of `LOG.md`.

A session that scopes without producing a spec never leaves `scoping`, because `write-plan` never
runs. That is correct for T0/T1 work.

**`MISSION.md` is lossy by design.** It is the only file in `.workspace/` that may be overwritten.
Because everything durable is append-only, a clobber by a concurrent session costs a stale pointer,
never work.

### `LOG.md`

The accumulated output of `brainstorm` and `grill` is not disposable scratch — it is an ordered
ledger of settled decisions with their evidence, rejected alternatives, and consequences, plus the
threads still open. It is the direct input to `write-plan`.

The old harness had the right *shape* (`specs/<slug>.thoughts.md` carried typed `DECISION` /
`QUESTION` entries); what was wrong was its **location** — committed and per-spec. `LOG.md` keeps the
shape and moves it to one untracked file per worktree.

### `history/`

Two record types: `handoff` and `finding`. Research results and verification runs are `finding`
records. Decisions are **not** history records — they accumulate in `LOG.md`, because a grilling
session produces many decisions in sequence and one ordered file is easier to append to and read
back than N timestamped files.

Records are immutable and carry **no status field**. Nothing tracks `open` / `resolved` / `promoted`
/ `wont-fix`.

Handoff records keep the existing skill's shape: Summary, Key decisions, **What did NOT work**, Code
changes, Open questions/blockers, Next steps.

**Write protocol.** Timestamps are `YYYYMMDDTHHMMSSZ` — readable, sortable. **Creation is atomic**
(`set -o noclobber` / `O_EXCL`): if the name exists the create *fails* and the writer retries with
`-2`, `-3`. Check-then-write is a race and is not permitted. `artifacts/` is written the same way and
is never overwritten, so an immutable record can never come to reference mutated evidence.

### Concurrency

**No locking, no append protocol, no staleness check.** Multiple sessions in one worktree share the
checkout, branch, and `.workspace/`. The exposure is structurally small: `history/` records cannot
collide **given the atomic-creation rule above**, `MISSION.md` is lossy by design, and `LOG.md` is
the only file with genuine concurrent-write risk. That risk is accepted. Revisit if it happens.

Depot will not arbitrate — it "exposes that concurrency and does not impose workflow semantics or
pretend to prevent file-level conflicts."

**Cross-worktree coordination** needs no mechanism: separate `.workspace/` directories, coordination
through committed specs, the issue tracker, and PRs.

### What is not automated

Stated so the contract does not imply machinery that does not exist:

- Two worktrees may both sit in `state: building` for the same spec. Nothing detects or prevents it.
- `abandoned` is informational. No process lists, sweeps, or acts on abandoned worktrees.
- **Automatic removal does exist** — see §7 — and it is not Depot's.
- Findings not promoted before removal are lost. Removal carries no obligation.

---

## 3. `specs/` — the build contract

```text
.workspace/LOG.md  →  specs/<slug>.md                     (T0–T2)
.workspace/LOG.md  →  specs/<epic>/README.md + 01-*.md    (T3)
```

**There is no scoping document.** Curated framing lives inside the spec, in sections that already
exist: `## Problem / Solution / User stories`, `## Out of scope`, `## Resolved decisions`. For a T3
epic the `README.md` is "shared context + ordered task list" — `depot/specs/control-plane-v1/README.md`
is the working exemplar.

**Retired outright:**

| Surface | Replaced by |
| --- | --- |
| `specs/<slug>.thoughts.md` | `.workspace/LOG.md` |
| `specs/<slug>.sessions/` | `.workspace/history/<utc>-handoff-<slug>.md` |
| `.context/<slug>.md` | `.workspace/LOG.md` |
| `specs/<slug>.scoping.md` | never created |

**The spec pointer is one field.** `MISSION.md`'s `spec:` records a repo-relative path, written like
any other part of the file. The word "bind" is not part of the vocabulary.

**Deleted:** any `bind` command or CLI, `make work SPEC=`, `.claude/active-spec`, the
`{path, commit}` source-commit pin, drift detection, and any rebind procedure. Rebinding is editing
the field.

**Cross-worktree spec sharing.** Because `wt` always branches from `origin/main`, a spec must be
**merged** — not merely committed — before parallel build worktrees are cut. This is already the
observed practice: melting's `specs/build-week/` sits on `origin/main` and six worktrees build from
it.

---

## 4. `docs/` — durable repository truth

```text
docs/
  INDEX.md            routes; docs/ is flat
  architecture.md     current system shape
  glossary.md         domain language
  adrs/               accepted, durable decisions
  agent-guidance/     project adapters for generic skills
```

`docs/` holds durable repository truth **only**. `agent_docs/` is retired everywhere.

**Planning and research artifacts live under `specs/<epic>/`**, with the work they inform. They age
out with their epic instead of accumulating as permanent documentation. No `building/` namespace.

⚠ **The `agent_docs/` retirement is not "delete `agent_docs/`, keep `docs/`."** Where both exist the
`agent_docs/` copy is consistently larger — the `docs/` copies are stubs from an unfinished
migration. In melting-v2: `architecture.md` 75 vs 55 lines, `glossary.md` 65 vs 24, `revisit.md` 153
vs 9, all divergent. Reconciliation is per-file, with a human.

### Promotion

**There is no enforcement machinery** — no status fields, no pre-removal checklist, no export or
archive step. `.workspace/` is disposable and worktree removal carries zero obligation.

Promotion is a conversation, in two forms:

1. **Opportunistic, any time.** An agent that notices something worth promoting — an ADR, a glossary
   entry, an architecture correction, an issue — **says so and asks**. It never creates one silently.
2. **At merge**, because that is when the decision is real. **The promotion ships as a separate PR**,
   so documentation never blocks code.

**Consequent requirement:** because the worktree — and `LOG.md` with it — may be gone by merge time,
**the PR description must carry the settled decisions from `LOG.md`.** The PR body is the bridge: it
survives the worktree and is what you are looking at when you merge. It is the *only* preservation
mechanism, and nothing checks that it happened.

---

## 5. The machine

```text
~/.agents/                       installed projection: skills/ agents/ rules/ hooks/
~/.claude/                       real directory: Claude runtime state + adapter
~/.codex/                        real directory: Codex runtime state + adapter
~/.config/agents/projects.yaml   the single project registry
~/.config/agents/secrets.env     machine secrets (chmod 600, sourced from ~/.zshrc)
~/.config/git/ignore             contains .workspace/
~/.local/bin/wt                  the worktree command
```

Provider homes symlink individual source subdirectories (`~/.claude/skills → ~/.agents/skills`),
never the whole tree. **`~/agents/` is retired** — Conductor's archives move to `~/.conductor/`.

Two names differing by one character (`~/agents` vs `~/.agents`) meaning entirely different things
is a real write-to-the-wrong-tree failure mode; removing one name eliminates it.

### Source layout and installation

The harness repo carries two payloads. `core/` is installed to the machine; `adopt/` is copied into
a target repo. They are never conflated:

```text
core/                      → ~/.agents/
  skills/                  shared — both providers read SKILL.md
  hooks/                   inject-global-rules.sh only (see K)
  rules/                   injected by inject-global-rules.sh
  claude/agents/           4 × .md + frontmatter
  codex/agents/            4 × .toml + developer_instructions

adopt/                     → a target repo
  AGENTS.template.md       → AGENTS.md — THE profile (see L)
  CLAUDE.template.md       → CLAUDE.md — a stub that @AGENTS.md
  hooks/                   → .claude/hooks/ — one copy, two bindings (see K)
  settings.json            → .claude/settings.json   (Claude binding)
  codex/hooks.json         → .codex/hooks.json       (Codex binding)
  Makefile, make/, specs/
```

⚠ **Amended by decision K.** The six safety hooks and `spec-session-orient.sh` are **repo-owned**,
not machine-installed: `$(git rev-parse --show-toplevel)` only resolves if the scripts are inside
the repo, so hooks cannot both live at `~/.agents/hooks/` and be bound that way. `adopt/` carries
them. `inject-global-rules.sh` stays machine-level because it exists to fire *outside* projects.
Machine-wide registration of the safety hooks is deferred, so Wave 1 T1.8 is descoped.
Also, a repo never carries a second copy of its profile — see decision L.

Agent formats differ per provider, so the four agents exist as eight files. Any change to an agent
touches both.

**`install.sh`** builds into a temp tree and swaps; keeps one backup (`~/.agents.prev`); is
idempotent; **prunes only with `--prune`**; **refuses to run when a file in `~/.agents/` differs from
its source**, naming the file; supports `--dry-run`; migrates `~/.config/depot/projects.yaml` →
`~/.config/agents/projects.yaml` only when the target is absent; installs `wt` to `~/.local/bin/`.
It **verifies provider capabilities** — that `WorktreeCreate` registers and the worktree-location
settings exist — rather than asserting a version number.

**`adopt-harness/copy.sh`** copies `adopt/`, creates the `.agents/skills → .claude/skills` symlink
that Codex requires, and installs both providers' hook bindings. It no longer copies
`.claude/FLOOR.md`, `agent_docs/`, `spec.thoughts.md`, `spec.sessions/`, or `*.context.md`.

Scaffolding is copied unconditionally; anything a repo fills in — `CLAUDE.md`, `AGENTS.md`,
`make/gate.mk`, and both binding files — is written **only when absent**, so re-adoption can never
undo filled-in work.

`Makefile:install-global` is retired.

### Machine-level instructions

Personal rules stay in `core/rules/*.md`, delivered by `inject-global-rules.sh`, **including its
suppression inside any repo that owns `.claude/` or `CLAUDE.md`** — there, the project's own contract
governs. `~/.claude/CLAUDE.md` is not created and `~/.codex/AGENTS.md` stays empty. Going native
would load personal preferences into every project, reversing a deliberate choice.

`.claude/FLOOR.md` is removed; its content is redistributed to the rules file, `verify-before-done`,
`specs/README.md`, and each project's `AGENTS.md`. **The quality gate is not deleted** — it moves to
the project's `AGENTS.md` and §6 below.

### Secrets

| Tier | Where | Provisioned by |
| --- | --- | --- |
| Machine/personal | `~/.config/agents/secrets.env` | manually |
| Project | the project's own `.env` convention, gitignored | `make setup` |

The harness **never writes either** and only ever references `${VAR}`.

⚠ **Governing invariant:** machine secrets never live in a tree that is a candidate for versioning
or syncing. `~/.agents/` is exactly that tree.

### Layering

Placement is decided by **portability**, not frequency:

> **The core test:** would this be correct and useful in a repository I have never seen, with zero
> configuration?

| Layer | Home |
| --- | --- |
| Universal core | `core/`, installed to `~/.agents/` |
| Project layer | the repo's `.claude/` + `docs/agent-guidance/` |
| Area pack | opt-in per project or provider; never global |

Portability beats frequency because it is testable by inspection. "Frequently used" is unfalsifiable
and drifts — which is how the current machine ended up with everything global. The test has real
bite: it moves `ship` to the project layer, keeps `adopt-harness` in core, and removes E2E from the
harness entirely.

### Catalog

| Layer | Contents |
| --- | --- |
| **Core** | `brainstorm`, `grill`, `diagnose`, `tdd`, `verify-before-done`, `handoff`, `write-plan`, `adopt-harness`, `prototype`, `research`, `docs-drift`; agents `scout`, `researcher`, `reviewer`, `reviewer-security` |
| **Project** | `ship` / `open-a-pr`, `wayfinder`, `setup-matt-pocock-skills`, `domain-modeling` |
| **Area pack** | `teach`, `frontend-design`, browser/visualize/documents plugins |
| **Retired** | `overview-fresh`, `hatch-pet`, `grill-me`, `grilling`, `grill-with-docs` |
| **Unassigned** | `hot-mac` — unique unversioned source; preserve first, decide later |
| **Builtin, do not vendor** | `/simplify` |

**The grill collapse.** Three overlapping skills become one core `grill`. It keeps `grill-me`'s
one-decision-at-a-time discipline and `grill-with-docs`'s grounding in repository documentation, but
**strips the automatic doc creation** — precisely the behaviour promotion policy forbids. The merged
skill proposes candidates and asks.

`overview-fresh` is retired because its premise — a spec directory holding `overview.html`,
`thoughts.md`, and `decisions/` — no longer exists.

`research` retargets its output to `.workspace/history/<utc>-finding-<slug>.md`.

### Provider parity

| Surface | Status |
| --- | --- |
| Skills | portable for Claude; **Codex requires the `.agents/skills` symlink** to discover project skills |
| Hooks | same event vocabulary and JSON envelope, **but edit payloads differ** — see below |
| Agents | divergent formats accepted. Claude `.md` + frontmatter, Codex `.toml` + `developer_instructions`. Dual-maintained, no generator |
| Plugins | project scoping is **untested**, not a known limitation. Verify in a disposable trusted repo |
| LSP | **not delivered by the harness.** No LSP plugin is installed on this machine. A per-project area-pack adoption check. Codex equivalence unassigned |

⚠ **Registration alone does not achieve hook parity.** Codex sends edits through `apply_patch`, so a
hook reading `.tool_input.file_path` / `.content` / `.new_string` silently no-ops on every Codex
edit. The two Bash guards are portable because both providers expose `.tool_input.command`.

The fix is on melting's `origin/main`: `protect-secrets.sh` falls back to flattening `tool_input` and
reading targets from `*** Add/Update/Delete File:` headers, with
`matcher: "Read|Edit|Write|apply_patch"`. That exact ref is the harvest source. Commit `95fa9b1`
(comment-bloat matcher tightening) is **not** on main and is not harvested.

**Hook command paths resolve from `$(git rev-parse --show-toplevel)`.** Melting's relative
`../.claude/hooks/…` form is not trusted — Codex is reported to resolve from session cwd, which would
break it. depot's and smoke-screen's absolute machine paths break on any repository move.

**Every hook is tested against both providers' real payloads** before Wave 1 is considered done.

⚠ **Codex hook trust is per-hash.** `~/.codex/config.toml [hooks.state]` stores
`trusted_hash = "sha256:…"` per entry, so every changed or newly registered hook is skipped until
approved. Installation is not complete until each hook is trusted **and observed to fire** — an
untrusted hook is indistinguishable from a registered one.

**Machine-level Codex runs only `inject-global-rules.sh`, and that is now correct.** Under decision
K the six safety hooks are registered **per repo** by `copy.sh`, which is what depot and
smoke-screen already do; machine-wide registration is deferred, not missing. Wave 1 T1.8 is reduced
to trusting the one machine hook and observing it fire.

**Security review model:** `reviewer-security` moves from `sonnet` to `opus`. Its invocation is now
rare and deliberate (§6), which is exactly when the strongest model is worth it.

---

## 6. Verification and shipping

```text
LOCAL, before the PR
  1. make check            hook-enforced by enforce-gate-on-stop.sh
  2. verify-before-done    run it, exercise it, report evidence

ASYNC, if the project has one
  3. the project's PR review bot reviews the diff

ON YOUR WORD ONLY
  4. reviewer / reviewer-security / /code-review — never automatic
  5. merge + promotion conversation → ships as a SEPARATE PR
```

**Two mandatory local steps. No automatic review of any kind.**

`reviewer` and `reviewer-security` run only when you ask. Both agents' self-triggering descriptions
are removed — `reviewer-security.md`'s "Trigger whenever the diff hits a hotspot, even a one-liner"
and `reviewer.md`'s "Trigger after an implementation is 'done' and before /ship" are the mechanism by
which they ran unbidden, and they are deleted. `/ship` gains no coverage logic; that can be added
later if the absence proves uncomfortable.

**Why `verify-before-done` survives as mandatory.** PR bots never run the code — they read the diff
and infer behaviour statically. `verify-before-done` covers exactly that gap, which is why it is the
one local step that is not redundant. It is not a review.

**PR review is a declared project capability, and nothing consumes the declaration.** A project
records whether it has an automatic bot; that is documentation. The reference implementation is
`smoke-screen/.github/workflows/claude-code.yml`.

⚠ **Accepted exposure.** Nothing blocks a merge anywhere: smoke-screen requires Build/Lint/Test but
**zero approvals** and its reviewer is not a required check; melting's workflow is `@claude`-mention
only; depot and the harness have none; melting's and the harness's `main` are unprotected. Sensitive
changes can reach main with no adversarial pass. This is deliberate and owned by the developer.

`ship` and `open-a-pr` are **not** competing surfaces — `ship` is a thin trigger that checks git
state and delegates to `open-a-pr` as the single source of truth for the procedure.

---

## 7. The day-to-day journey

**The default, and most work (T0–T2):**

```text
wt <project> --branch <b>   →   build   →   ship
```

No spec, no planning worktree, no state transition — `MISSION.md` stays `scoping` because
`write-plan` never runs.

**T3 adds the spec-merge-first sequence, and only T3**, because parallel worktrees need the spec on
`origin/main` to see it:

```text
1  wt <project> --branch plan/<slug>    planning worktree, off origin/main
2  brainstorm → grill                   → .workspace/LOG.md, findings → history/
3  write-plan                           → specs/<epic>/README.md + 01-*.md
                                          sets MISSION state:building, spec:
4  spec-only PR → merge to main
5  wt <project> --branch <task-N>  × N  each cut fresh from origin/main
6  each MISSION's spec: field → the same spec path
7  build in parallel
```

### Worktrees

`code/` is a **reference checkout** tracking `origin/main`; all work happens in `worktrees/`, a peer
of the container:

```text
~/melting/code/melting-v2/     checkout
~/melting/code/worktrees/<b>
~/smoke/code/smoke-screen/
~/smoke/code/worktrees/<b>
~/dev/depot/
~/dev/worktrees/<repo>/<b>
```

**Three creators, one location.** `wt`, Depot, and both providers are all configured to write here.
`wt <project> --branch <b>` resolves the registry (or `git rev-parse --show-toplevel` inside a repo),
fetches, branches from **`origin/main`**, creates `.workspace/`, and runs `make setup` unless
`--no-setup`. Claude's `WorktreeCreate` hook does the same two jobs for Claude-created worktrees.

⚠ **Init is eager for `wt`, Depot, and Claude; lazy for Codex.** Codex has **no documented
`WorktreeCreate`-equivalent hook**, so a Codex-created worktree gets `.workspace/` and `make setup`
at first SessionStart rather than at creation. The asymmetry is accepted, not overlooked: the
observable difference is that dependencies install a few seconds later. If Codex has or gains an
equivalent hook, it registers the same script.

`ensure-workspace.sh` on SessionStart is the net for everything else — Codex, plain
`git worktree add`, a setting that did not take, or a path not yet known. `.workspace/` is an
invariant of *a worktree an agent works in*, not of one command.

**SessionStart also orients**, read-only: `MISSION.md`'s state and next action, the spec path, the
newest handoff **filename**, the finding **filenames**, and brief `git status`. Filenames only, never
contents. There is no `orient` skill.

⚠ **Hook order is load-bearing.** `ensure-workspace.sh` must be registered **before**
`spec-session-orient.sh` in both providers' SessionStart lists. Orientation reads what the
initializer creates; reversed, the first session in a fresh worktree orients against nothing.

### Cleanup — owned by the creator

| Creator | Removal |
| --- | --- |
| `wt`, Depot | Depot's guarded trash |
| Claude | its own cleanup on exit/archive, plus the temporary sweep |
| Codex | its own cleanup on archive/retention, which saves snapshots |
| plain `git worktree add` | manual |

**Provider automatic cleanup stays enabled.** 101 secondary worktrees already exist across the four
repos, so the sweeps are not keeping up as it is.

⚠ **A retention sweep can remove a worktree you never explicitly retired**, taking `.workspace/` and
`LOG.md` with it. The only mitigation is the PR body.

**Phone path:** Depot's daemon, worktree creation, and tmux launch all run on the machine, so a
phone-attached session fires the machine's SessionStart hook and `.workspace/` appears. No Depot
change required.

---

## 8. Explicitly rejected

| Rejected | Why |
| --- | --- |
| Depot owning `.workspace/` | ADR 0004 accepted and shipped; re-coupling Depot to one harness's schema is what it was written to prevent |
| `depot worktree create` / `workspace init` / `orient` / `bind` | none exist; the harness must not require Depot |
| A second registry at `~/.config/agents/projects.toml` | `~/.config/depot/projects.yaml` already exists and is populated; two catalogs is the one bad outcome |
| `specs/<slug>.scoping.md` | a third home for content the spec's own sections already own |
| `specs/<slug>.thoughts.md`, `.sessions/`, `.context/` | four task-context surfaces collapse to `LOG.md` + `history/` |
| `workspace_id` | zero consumers; needs an identity registry the harness refused to build |
| `{path, commit}` spec pinning and drift detection | fires mostly on the builder's own legitimate edits |
| Schema validation, repair, `workspace_changed` staleness errors | the machinery that made the old model burdensome; already deleted from Depot |
| Finding status fields | cannot coexist with immutable history records |
| Locking or an append protocol | rare on a single-human machine; atomic creation closes the only real hole |
| Workspace export / archive before removal | preserves things with no value and produces an archive nobody reads |
| `~/agents/` as canonical root | one character from `~/.agents/`; never was a canonical source |
| Frequency as the layering criterion | unfalsifiable; how everything ended up global |
| Automatic `reviewer` / `reviewer-security` | the developer decides when review happens |
| A `--base` flag on `wt` | `origin/main` is absolute; merge the spec first |
| A `building/` namespace | `specs/` already does this |
| Native `~/.claude/CLAUDE.md` replacing the injection hook | would load personal preferences into every project, reversing the deliberate suppression |
| A harness E2E skill | fails the portability test; smoke-screen keeps its own |
| A Codex `/simplify` equivalent | an ordinary instruction, not a skill |
| A universal cleanup mechanism | the creator owns removal |
| Check-then-write history filenames | a race; atomic creation instead |

---

## 9. What must be built

| # | Component | Note |
| --- | --- | --- |
| 1 | `install.sh` | publishes `core/` → `~/.agents/`; the Wave 0 gate |
| 2 | Rewritten `adopt-harness/copy.sh` | `adopt/` payload, `.codex/` binding, `.agents/skills` symlink |
| 3 | `ensure-workspace.sh` | idempotent initializer. **Must be a separate script** from `inject-global-rules.sh`, whose core logic exits early whenever an ancestor has `.claude/` or `CLAUDE.md` — i.e. in every adopted repo, exactly where init is needed |
| 4 | `wt` | installed to `~/.local/bin/` |
| 5 | `grill` | merge of `grill-me`, `grilling`, `grill-with-docs` |
| 6 | `AGENTS.template.md` | does not exist; why adopted repos come out Claude-only |
| 7 | The harness repo's own `AGENTS.md` | the only one of four repos without one |
| 8 | Registry migration | `~/.config/depot/projects.yaml` → `~/.config/agents/projects.yaml` |

---

## 10. Migration sequence

### Wave 0 — harness repo authoring

No machine changes; fully reversible; unblocks everything.

1. **Snapshot and checksum** `~/.agents`, `~/.codex/skills`, and `~/agents/claude` before anything.
2. Import all **ten** unversioned skills into the repo at their assigned layer. `hot-mac` is
   preserved with its layer undecided.
3. Restructure into `core/` and `adopt/`, including `claude/agents/` and `codex/agents/`.
4. Write `install.sh` and rewrite `copy.sh`.
5. Write `ensure-workspace.sh` and `wt`; author the registry migration.
6. Author `grill`; delete `grill-me`, `grilling`, `grill-with-docs`, `overview-fresh`.
7. Retarget `brainstorm`, `write-plan`, `handoff`, `research` to `LOG.md` / `history/`, with atomic
   writes. Remove `write-plan`'s automatic ADR creation.
8. Assign the `MISSION.md` owners in `write-plan`, `handoff`, `ship`.
9. Rewrite `spec-session-orient.sh`: read `MISSION.md`, drop the self-bind write, add orientation.
10. Harvest melting's `origin/main` Codex hook fix; rewrite bindings to resolve from
    `git rev-parse --show-toplevel`; author both-provider payload tests.
11. Rewrite both reviewer descriptions (four files); `reviewer-security` → `opus`.
12. `open-a-pr`: carry `LOG.md` decisions into the PR body.
13. Remove `FLOOR.md`, the `Makefile` `work` target, `.claude/active-spec`, template companions; fix
    `CLAUDE.template.md`'s `@.claude/FLOOR.md` import.
14. Write `AGENTS.template.md` and the harness's own `AGENTS.md`.
15. Rewrite `specs/README.md` and `.claude/rules/specs.md`.
16. Reconcile `agent_docs/` → `docs/`; move planning artifacts to `specs/harness-standardization/`.
17. Rewrite `HIGH-LEVEL-CONTEXT.md`; supersede the legacy `01`–`08` files.
18. Write the disposable two-provider acceptance scenario.

### Wave 1 — machine

Highest risk. Requires a standalone script or a Codex session — Wave 1 moves Claude's live runtime
state and cannot be performed by the Claude session doing the work.

19. `~/.config/git/ignore` += `.workspace/`.
20. Establish `~/.config/agents/secrets.env`; update `~/.zshrc` and both rule files.
21. Run `install.sh --dry-run`, reconcile the two drifted skills, then install.
22. Undo the `~/.claude` symlink; symlink provider subdirectories to `~/.agents/`.
23. Retire `~/agents/`; move Conductor archives to `~/.conductor/`.
24. Migrate the registry; rewrite `worktree_root` values; add `depot`.
25. Configure both providers' worktree roots; register `WorktreeCreate`.
26. Register the six safety hooks in `~/.codex/hooks.json`; **trust each hash and observe each fire**.
27. Run the Codex plugin-scoping experiment in a disposable trusted repo.

### Wave 2 — projects

28. `depot`: `agent_docs/` → `docs/`; mark `workspace-memory-v1` superseded; adopt the registry path;
    fix absolute hook paths.
29. `smoke-screen`: fix absolute hook paths; fold `smoke-worktrees/` into `worktrees/`.
30. `melting-v2`: per-file documentation merge; rewrite `workspace.md` and `agent-environment.md`;
    clean up the stray nested `worktrees/.claude/worktrees/`.
31. **End-to-end verification:** `wt` a worktree, scope, spec, build, ship, merge, promote, remove —
    on both providers.

### Wave 3 — deferred, non-blocking

32. Depot `post_create_cmd` sub-spec.
33. `hot-mac` layer decision.
34. `/ship` review-coverage logic, if the absence proves uncomfortable.

---

## 11. Blockers

1. **Eight components do not exist** — see §9.
2. ⚠ **Ordering hazard.** Ten skills exist only on disk, unversioned. Wave 1 rebuilds the machine
   tree — run it before Wave 0 step 2 and they are lost. **Step 1 is the snapshot, and it is first
   for this reason.**
3. ⚠ **`~/.agents/skills` has already drifted** from the repo (`adopt-harness`, `docs-drift`).
   `install.sh` will refuse until this is reconciled by hand. Intended.
4. ⚠ **Chicken-and-egg.** Wave 1 moves Claude's live runtime state and cannot be performed by a
   Claude session. Needs a standalone script or a Codex session.
5. **melting-v2's documentation merge needs human per-file decisions** and cannot be automated.
6. **Four provider behaviours are documented by current official sources but not locally
   acceptance-tested:** Codex resolving hook commands from session cwd; Codex aliasing `Edit`/`Write`
   onto `apply_patch`; the Claude Desktop worktree-location setting; the Codex worktree-root setting.
   They are not assumptions — they are untested dependencies, and Wave 1 tests each. Each has a safe
   fallback.
7. **`code/` as a reference checkout is a change of practice.** All four checkouts are currently on
   task branches and dirty.
