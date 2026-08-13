---
status: ready
tier: T3
hotspots: [provider-config, worktree-lifecycle, secret-handling, harness-propagation, destructive-migration]
---

# Harness standardization — execution plan

The ordered, executable plan. Every task below derives from a settled decision; none of them
reopens one.

**Authority:** [`../DECISIONS-PENDING.md`](../DECISIONS-PENDING.md) → [`../CONTRACT.md`](../CONTRACT.md) →
[`../HARNESS-DEPOT-OPERATIONAL-DESIGN-REVIEW.md`](../HARNESS-DEPOT-OPERATIONAL-DESIGN-REVIEW.md) →
this file. Where any two disagree, the higher wins.

**Superseded and not executable:** `../README.md`, `../01-*.md` … `../08-*.md`,
`../PRE-IMPLEMENTATION-CONTRACT-AUDIT.md`, `../HIGH-LEVEL-CONTEXT.md`. Each carries a banner.
Harvest research from them; do not run their instructions.

**This file replaces the previous 14-task plan**, which assumed `~/agents` as canonical,
`thoughts.md`, typed workspace history, a scoping-synthesis step, `depot workspace` commands,
bind-with-commit, and archive-before-removal. All six are void.

---

## Wave −1 — make the contract durable

**Prerequisite to everything. Not an implementation task.**

Commit the reconciliation as a **docs-only** change and merge it to `main` before any Wave 0 work
begins. Starting implementation while the contract is untracked would mix the authority baseline
with its own implementation and destroy both rollback and provenance — there would be no committed
"before" to diff against or revert to.

**Scope:** `specs/harness-standardization/**` and the `docs/` provenance it references. No code, no
scripts, no machine changes.

**Acceptance:** `main` contains the reconciled contract; `git log` shows the authority baseline as a
single reviewable change; **Wave 0 begins in a fresh worktree cut from that commit**, in a fresh
chat.

---

## Wave 0 — harness repo authoring

No machine changes. Fully reversible. Unblocks everything.

### T0.1 — Snapshot and checksum

**Depends on:** Wave −1 merged. **First implementation task — nothing precedes it.**

Snapshot and checksum `~/.agents`, `~/.codex/skills`, `~/.claude/skills`, and `~/agents/claude` into
the harness repo as an audit artifact. Ten skills exist only on disk and Wave 1 rebuilds the machine
tree.

**Acceptance:** every unique file in all four trees is checksummed and recoverable; the report names
the ten unversioned skills and the two already-drifted ones (`adopt-harness/SKILL.md`,
`docs-drift/SKILL.md`).

### T0.2 — Import the ten unversioned skills

**Depends on:** T0.1

Import `domain-modeling`, `grill-with-docs`, `grilling`, `hatch-pet`, `hot-mac`, `prototype`,
`research`, `setup-matt-pocock-skills`, `teach`, `wayfinder` at their assigned layer (CONTRACT §5).
`grill-with-docs` and `grilling` are imported **as source** and then consumed by T0.6.

**Acceptance:** no skill exists only on disk. `hot-mac` is preserved with its layer explicitly
recorded as undecided. Sources for retired skills are preserved even though they will not install.

### T0.3 — Restructure into `core/` and `adopt/`

**Depends on:** T0.2

Build the two payloads (CONTRACT §5), including `core/claude/agents/` and `core/codex/agents/`.

**Acceptance:** `core/` contains nothing project-specific and `adopt/` contains nothing
machine-installed; the four agents exist as eight files; no secrets anywhere in `core/`.

### T0.4 — `install.sh`

**Depends on:** T0.3. **This is the Wave 0 gate.**

Temp-tree-then-swap; one backup at `~/.agents.prev`; idempotent; `--prune` opt-in; **refuses when a
file in `~/.agents/` differs from source**, naming it; `--dry-run`; migrates the registry only when
the target is absent; installs `wt` to `~/.local/bin/`; **verifies** `WorktreeCreate` and the
worktree-location settings rather than asserting a version.

**Acceptance:** `--dry-run` against the current machine reports every drifted file and exits
non-zero; a second run after reconciliation succeeds; running twice produces an identical tree.

⚠ **Corrected 2026-08-09, after T0.16 re-measured it.** This line originally predicted "the two
drifted skills". By the end of Wave 0 the real count is **8**, because Wave 0 legitimately rewrote
six of them (T0.5, T0.6, T0.9, T0.13). With no install manifest present, `install.sh` cannot
distinguish a Wave 0 rewrite from a hand-edit and correctly refuses on all eight. See T1.3.

### T0.5 — Rewrite `adopt-harness/copy.sh`

**Depends on:** T0.3

Copy `adopt/`; create the `.agents/skills → .claude/skills` symlink Codex requires; install the
`.codex/` binding. Stop copying `.claude/FLOOR.md`, `agent_docs/`, `spec.thoughts.md`,
`spec.sessions/`, `*.context.md`.

**Acceptance:** a disposable adopted repo is discoverable by **both** providers; no retired surface
travels; re-running does not clobber filled-in work.

### T0.6 — `grill`

**Depends on:** T0.2

Merge `grill-me`, `grilling`, `grill-with-docs` into one core skill: one decision at a time, grounded
in `docs/`, **proposes** promotion candidates and never writes them. Delete the three plus
`overview-fresh`.

**Acceptance:** no skill creates an ADR, glossary entry, or architecture change without asking.

### T0.7 — `ensure-workspace.sh` and `wt`

**Depends on:** T0.3

`ensure-workspace.sh`: idempotent, fails open, no-op outside git, **never overwrites an existing
`MISSION.md`**, tolerates malformed frontmatter by using defaults and reporting textually, reports an
absent spec path but never repairs it. It **must be a separate script** from
`inject-global-rules.sh`, whose core logic exits early in exactly the repos where init is needed.

`wt`: per CONTRACT §7, including the registry read via `python3 -c`, `origin/main` base, last-path-
segment directory naming, refuse-on-collision, keep-worktree-on-setup-failure, and `--no-setup`.

**Acceptance:** both run against a disposable repo; every refusal case in CONTRACT §7 is exercised;
`ensure-workspace.sh` is idempotent across ten runs.

### T0.8 — Registry migration

**Depends on:** T0.4

Migrate `~/.config/depot/projects.yaml` → `~/.config/agents/projects.yaml`, rewrite the four
`worktree_root` values to the `<container>/worktrees/` layout, add the missing `depot` project.

**Acceptance:** the migrated file parses in both `wt` and Depot; the original is left untouched until
Wave 1.

### T0.9 — Retarget the workspace-writing skills

**Depends on:** T0.2, T0.6

Retarget `brainstorm`, `write-plan`, `handoff`, `research` to `.workspace/LOG.md` and
`.workspace/history/` with **atomic `O_EXCL` creation and `-2` retry**. Remove `write-plan`'s
automatic ADR creation. Assign the `MISSION.md` owners (CONTRACT §2) in `write-plan`, `handoff`, and
`ship`.

**Acceptance:** no skill references `thoughts.md`, `.sessions/`, `.context/`, or `agent_docs/`; two
concurrent writers producing the same name both survive; `write-plan` sets `state: building`.

### T0.10 — Rewrite `spec-session-orient.sh`

**Depends on:** T0.7

Read `MISSION.md`'s `spec:` instead of `.claude/active-spec`; **remove the self-bind write**; add
read-only orientation — state, next action, spec path, newest handoff **filename**, finding
**filenames**, brief `git status`.

**Acceptance:** the hook writes nothing; stays silent when nothing resolves; prints filenames only.
**Registration order is load-bearing** — `ensure-workspace.sh` must precede this hook in both
providers' SessionStart lists, or the first session in a fresh worktree orients against nothing.
Verify by opening a session in a brand-new worktree, not an existing one.

### T0.11 — Codex hook parity

**Depends on:** T0.3

Harvest the `protect-secrets.sh` fix and the `apply_patch` matcher from melting
**`origin/main`** — record the exact blob SHA. Do **not** harvest `95fa9b1`. Rewrite all bindings to
resolve from `$(git rev-parse --show-toplevel)`.

**Acceptance:** every hook is exercised against **both** providers' real payloads, including a Codex
`apply_patch` for an ordinary edit (exit 0), a `.env.local` write (exit 2), and a synthetic API key
(exit 2). Path resolution is verified from a subdirectory, not just the repo root.

### T0.12 — Reviewers and shipping

**Depends on:** T0.3

Delete both self-trigger descriptions across **four** files; `reviewer-security` → `opus`; teach
`open-a-pr` to carry `LOG.md` decisions into the PR body.

**Acceptance:** neither agent's description implies automatic invocation; a PR body produced from a
populated `LOG.md` contains its settled decisions.

### T0.13 — Retire the old surfaces

**Depends on:** T0.5

Remove `.claude/FLOOR.md` and redistribute its content (CONTRACT §5 — **the gate is retained**);
remove the `Makefile` `work` target, `.claude/active-spec` and its ignore entry,
`specs/templates/*/spec.context.md`, `spec.thoughts.md`, `spec.sessions/`. **Fix
`CLAUDE.template.md:7`'s `@.claude/FLOOR.md` import in the same change.**

**Acceptance:** no dangling import; a repo-wide search for the retired conventions returns only
historical documents.

### T0.14 — Instruction files and documentation

**Depends on:** T0.13

Write `AGENTS.template.md` and the harness repo's own `AGENTS.md`. Rewrite `specs/README.md` and
`.claude/rules/specs.md`. Reconcile `agent_docs/` → `docs/`. Move planning artifacts into this epic.
Banner `HIGH-LEVEL-CONTEXT.md`, `README.md`, and `01`–`08` as superseded.

**Acceptance:** one documentation namespace; every superseded document says so in its first ten
lines; authority order stated identically everywhere it appears.

### T0.15 — Acceptance scenario

**Depends on:** all of Wave 0

Write the disposable two-provider scenario Wave 2 will run: adopt a throwaway repo, create a worktree
with `wt` and with each provider, orient in both, scope, spec, build, ship, remove.

**Acceptance:** every CONTRACT §7 claim maps to a step; every step has an observable result.

### T0.16 — Explicit adversarial and security review

**Depends on:** all of Wave 0, including a passing T0.15 run.

**Requested explicitly by the developer for this wave**, notwithstanding the standing policy that no
review runs unless asked (CONTRACT §6). Wave 0 is the exception that earns it: it authors the
installer that writes the machine tree, the safety hooks that gate every edit, and the review
machinery itself. A defect here is silent and propagates to every repo.

Run **both** `reviewer` and `reviewer-security` against the complete Wave 0 diff. Security scope, at
minimum:

- `install.sh` — the swap, the backup, the refuse-on-drift check, and `--prune`. Can any path delete
  or overwrite something unrecoverable? What happens if it is interrupted mid-swap?
- `wt` — registry parsing, branch and path handling, and the refusal cases. Any injection surface
  from a registry value or branch name?
- The Codex hook bindings — confirm `protect-secrets.sh` **blocks** on a real `apply_patch` payload
  and does not fail open, and that path resolution holds from a subdirectory.
- `ensure-workspace.sh` — confirm it can never overwrite an existing `MISSION.md`.
- Confirm no secret value is written to any file by any new script.

**Acceptance:** both reviews run and their findings are resolved or explicitly accepted in writing.
**Wave 1 does not start until this task closes.**

---

## Wave 1a — machine activation

⚠ **Restructured 2026-08-09 by decision M** (`../DECISIONS-PENDING.md`, pass 4). The old Wave 1
conflated *activating the converged harness* — additive, or an in-place upgrade of harness-owned
territory — with *cleaning up the machine's historical layout*, which moves Claude's live runtime
state for hygiene value only. Wave 1a is the activation; the cleanup is **Wave 1b** below,
deferred unscheduled. Wave 1a touches no live runtime state, so it **can** be performed from a
Claude session — but run T1.4a and the provider settings edits with no live session anyway: they
swap directories the providers read.

### Preflight — before anything touches the machine

| # | Task | Note |
| --- | --- | --- |
| PF1 | Push the branch off-box | the whole epic exists on one disk, and Wave 1a mutates that machine. Developer action |
| PF2 | Apply the melting S1 patch — T2.3a | **unblocked now**: it needs nothing from Wave 1a. The live CRITICAL rename-onto-`.env` hole closes before anything else happens |
| PF3 | Fix `ensure-workspace.sh`'s frontmatter parse; regression-test it | found live 2026-08-09: its report path reads `spec:` without stripping the inline comment, so the very template its own create path writes triggers "points at a spec that does not exist: null # or specs/<slug>.md" on every SessionStart after the first. `spec-session-orient.sh:30` carries the correct `sub()` — the same parse exists twice, divergently. Fix to one shape, then mutate and watch the warning fire only when it should |
| PF4 | Author `install.sh --review` — decision N | the inbound channel: every extra and drift as an inbox with per-file *import / prune / leave*, plus a read-only survey of the non-symlinked provider locations. Sandbox-tested like the rest of `install.sh`. T1.3's reconciliation uses it |
| PF5 | Author the adoption version stamp — decision O | `copy.sh` records the harness commit in the adopted repo; a check reports staleness. The outbound channel: decision K's accepted consequence gets its mitigation |
| PF6 | Fresh-machine install case | an explicit `install.test.sh` case: a full run against an empty sandbox `$HOME`. The second-machine path is this case with real paths |

### The machine steps

The command / verify / rollback sequence for these rows is [`WAVE-1A-RUNBOOK.md`](./WAVE-1A-RUNBOOK.md).
This table stays the authority for *what and why*; the runbook is the *how* for the live session.

| # | Task | Note |
| --- | --- | --- |
| T1.1 | `~/.config/git/ignore` += `.workspace/` | ✅ **DONE 2026-08-09**, pulled forward out of wave order on the developer's instruction — Wave 0 proved that until it landed, any `git add -A` in a worktree committed task memory and propagated it to every worktree cut afterwards. Verified: `.workspace/` is ignored and survives `git add -A`. Backup at `~/.config/git/ignore.pre-workspace.bak` |
| T1.2 | Establish `~/.config/agents/secrets.env`; update `~/.zshrc` and both rule files | never move secret *values* by script. **Pulled into 1a by decision M**: the file currently sits inside `~/agents/claude/`, a tree whose siblings are versioned and copied — the live §5-invariant violation. Leave the old file in place until the new path is verified end-to-end |
| T1.3 | `install.sh --review`; reconcile the **8** flagged files by hand; install **with `--prune`** | see the note below — the refusal is expected, but the count and the prune decision are not what this row originally said. **Prune never runs blind** (decision N): the review pass precedes it |
| T1.4a | Symlink the provider skill/agent subdirs to `~/.agents/` **through the existing topology**; re-point the rules injection | `~/agents/claude/skills` etc. themselves become the symlinks; displaced real directories are **moved aside** (`.pre-harness` suffix), never deleted. Without this, Claude keeps reading the old real dirs and the machine never converges. Also re-point the Claude SessionStart injection to `~/.agents/hooks/inject-global-rules.sh` — otherwise the machine keeps injecting old rules from the old tree, *silently*, because the hook fails open |
| T1.6 | Activate the migrated registry | ⚠ between T1.6 and T2.1, `wt` reads the new registry while Depot reads the old — **freeze registry edits during the window**, or mirror them by hand |
| T1.7 | Configure both providers' worktree roots; register `WorktreeCreate` | falls back safely if a setting is absent |
| T1.8 | Trust `inject-global-rules.sh` in `~/.codex/hooks.json` and observe it fire | **descoped by decision K** — the six safety hooks are repo-owned, registered by `copy.sh` |
| T1.9 | Codex plugin-scoping experiment, **and how Codex treats a hook exit code of 127** | in a **disposable** trusted repo. 127 is what a binding returns if `git rev-parse` fails inside the repo; every hook fails OPEN on a missing `jq`, so this is the one dependency that degrades into undefined behaviour. Decide with data (T0.16 #8). **Needs nothing from the other steps — may run first** |
| T1.10 | Remove the `overview-fresh-check` scheduled task | it targets a skill `--prune` deletes; left in place it fails on every scheduled firing, orphaned |

### T1.3 — measured, not predicted (added by T0.16, 2026-08-09)

`./install.sh --dry-run` was run read-only against the real machine at the end of Wave 0
(`~/.agents/` hashed identically before and after). It exits 1 and reports:

- **8 files refused**, not two: `adopt-harness/{SKILL.md,copy.sh}`, `brainstorm`, `diagnose`,
  `docs-drift`, `handoff`, `verify-before-done`, `write-plan`. **Six are Wave 0's own rewrites**,
  not machine drift — but with no manifest present `install.sh` cannot tell, and refusing is
  correct. Disposition for all eight is **repo-wins**, except `adopt-harness/SKILL.md` and
  `docs-drift/SKILL.md`, which must be *read first*: T0.1 found the installed copy carries an
  in-place `CLAUDE.md`→`AGENTS.md` rewrite that is **buggy** (it documents a `.Codex/` path that
  does not exist), so repo-wins is right there too, but for a reason worth confirming by eye.
- **`keep 4`**, including `skills/grill-me/SKILL.md` and `skills/overview-fresh/SKILL.md` —
  both **retired** by CONTRACT §5. Without `--prune` they stay installed and T0.6's grill collapse
  never reaches the machine. **T1.3 must therefore run `--prune`**, having first confirmed the
  other two kept files (`open-a-pr/`, now a project-layer skill) are wanted elsewhere or gone.

**Wave 1a acceptance:** both providers start cleanly in a neutral directory and in an adopted
repo; a core skill resolves through the symlink chain from **both** providers; global rules
inject from `~/.agents/rules/`; every registered hook is observed to fire; no secret value was
written to any file; `~/.agents.prev` exists; the `--review` pass preceded `--prune`; and a
rollback was rehearsed.

---

## Wave 1b — machine cleanup (deferred, unscheduled — decision M)

The hygiene half of the old Wave 1. It runs only on an explicit later decision — or never; a
fresh machine never needs it. Until it runs, the accepted residue is the `~/agents` vs
`~/.agents` one-character hazard and the two-hop symlink topology.

| # | Task | Note |
| --- | --- | --- |
| T1.4b | Undo the `~/.claude` symlink; move the runtime state (~903 MB) into a real `~/.claude/` | **no live Claude session; non-Claude operator** |
| T1.5 | Retire `~/agents/`; Conductor archives → `~/.conductor/` | inventory before removing — the T0.1 snapshot is the record, not a copy of the runtime state |

**Preconditions if it ever runs:** a manifest-driven script rehearsed against a replica sandbox
`$HOME` built from the T0.1 inventory; `mv`-only until a verified end state; the rollback
rehearsed by killing the script mid-T1.4b and recovering.

---

## Wave 2 — projects

| # | Task | Depends on |
| --- | --- | --- |
| T2.1 | `depot`: `agent_docs/` → `docs/`; mark `workspace-memory-v1` superseded; adopt the registry path; replace absolute hook paths | Wave 1a |
| T2.2 | `smoke-screen`: replace absolute hook paths; fold `smoke-worktrees/` into `worktrees/` | Wave 1a |
| T2.3 | `melting-v2`: **per-file** documentation merge with a human; rewrite `workspace.md` and `agent-environment.md` off the Depot-owns-`.workspace/` model; clean the stray nested `worktrees/.claude/worktrees/` | Wave 1a |
| T2.3a | **CRITICAL security fix — apply `../patches/melting-protect-secrets-move-to.patch`** to melting. Its `protect-secrets.sh` does not path-check a `*** Move to:` rename destination, so a Codex agent can write a benign file and rename it onto `.env`. Verified diff, `git apply --check` clean against `origin/main`. **No dependency on the docs merge — do it first.** ⚠ Does not apply to `chore/melting-v2-docs-harness` as it stands: that branch is 27 commits behind and predates the `apply_patch` fallback. See `../patches/README.md` | **nothing — unblocked; run as Wave 1a preflight PF2** |
| T2.4 | Run T0.15 end-to-end on both providers | T2.1–T2.3 |

**Wave 2 acceptance:** each project's own gate is green; the acceptance scenario passes on both
providers; no project is declared aligned because a file merely exists. **And melting's
`protect-secrets.sh` is observed to BLOCK (exit 2) a real `*** Move to:` payload** — run it, do
not infer it from the patch having been applied.

---

## Wave 3 — deferred, non-blocking

| # | Task |
| --- | --- |
| T3.1 | Depot `post_create_cmd` sub-spec |
| T3.2 | `hot-mac` layer or retirement decision |
| T3.3 | `/ship` review-coverage logic, if the absence proves uncomfortable |
| T3.4 | Codex LSP disposition |

---

## Cross-task rules

- Work on a task branch in the affected repository; never make a machine-wide change from a default
  branch.
- Commit and push only when explicitly requested; each repository ships through its own PR.
- **Never bulk-delete** old paths, worktrees, caches, or runtime state. Inventory exact targets,
  preserve a recoverable copy, record the disposition.
- Keep secrets in environment-backed machine storage. Never write a value into the harness,
  workspace, docs, specs, logs, or examples.
- Prefer one source and links over copied text.
- Use the smallest layer that can carry a rule: machine, project, area, provider, or workspace.
- Run the affected repository's real checks and report observed results.
- **Do not claim a task done on unrun code.** Every acceptance line above is observable; observe it.

## Definition of Ready

- [x] Every decision is settled and recorded in `DECISIONS-PENDING.md`.
- [x] `CONTRACT.md` is reconciled against those decisions.
- [x] Stale documents are identified and bannered.
- [x] Task order, dependencies, and acceptance criteria are explicit.
- [x] The snapshot task is first, ahead of anything destructive.
- [x] The three unverified provider behaviours each have a safe fallback.
- [x] Wave 0 has been executed. *(T0.1–T0.16 complete; see `../WAVE-0-VERIFICATION.md` and
      `../T0.16-REVIEW.md`. `make check` green, 245 assertions across five suites.)*
