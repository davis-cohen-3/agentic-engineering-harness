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

**Acceptance:** `--dry-run` against the current machine reports the two drifted skills and exits
non-zero; a second run after reconciliation succeeds; running twice produces an identical tree.

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

## Wave 1 — machine

Highest risk. **Cannot be performed by the Claude session doing the work** — T1.4 moves Claude's live
runtime state. Use a standalone script or a Codex session.

| # | Task | Note |
| --- | --- | --- |
| T1.1 | `~/.config/git/ignore` += `.workspace/` | ✅ **DONE 2026-08-09**, pulled forward out of wave order on the developer's instruction — Wave 0 proved that until it landed, any `git add -A` in a worktree committed task memory and propagated it to every worktree cut afterwards. Verified: `.workspace/` is ignored and survives `git add -A`. Backup at `~/.config/git/ignore.pre-workspace.bak` |
| T1.2 | Establish `~/.config/agents/secrets.env`; update `~/.zshrc` and both rule files | never move secret *values* by script |
| T1.3 | `install.sh --dry-run`; reconcile the two drifted skills by hand; install | the refusal is expected |
| T1.4 | Undo the `~/.claude` symlink; symlink provider subdirs to `~/.agents/` | no live Claude session |
| T1.5 | Retire `~/agents/`; Conductor archives → `~/.conductor/` | inventory before removing |
| T1.6 | Activate the migrated registry | |
| T1.7 | Configure both providers' worktree roots; register `WorktreeCreate` | falls back safely if a setting is absent |
| T1.8 | Trust `inject-global-rules.sh` in `~/.codex/hooks.json` and observe it fire | **descoped by decision K** — the six safety hooks are repo-owned, registered by `copy.sh` |
| T1.9 | Codex plugin-scoping experiment | in a **disposable** trusted repo |

**Wave 1 acceptance:** both providers start cleanly in a neutral directory and in an adopted repo;
every registered hook is observed to fire; no secret value was written to any file; `~/.agents.prev`
exists and a rollback was rehearsed.

---

## Wave 2 — projects

| # | Task | Depends on |
| --- | --- | --- |
| T2.1 | `depot`: `agent_docs/` → `docs/`; mark `workspace-memory-v1` superseded; adopt the registry path; replace absolute hook paths | Wave 1 |
| T2.2 | `smoke-screen`: replace absolute hook paths; fold `smoke-worktrees/` into `worktrees/` | Wave 1 |
| T2.3 | `melting-v2`: **per-file** documentation merge with a human; rewrite `workspace.md` and `agent-environment.md` off the Depot-owns-`.workspace/` model; clean the stray nested `worktrees/.claude/worktrees/` | Wave 1 |
| T2.4 | Run T0.15 end-to-end on both providers | T2.1–T2.3 |

**Wave 2 acceptance:** each project's own gate is green; the acceptance scenario passes on both
providers; no project is declared aligned because a file merely exists.

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
- [ ] Wave 0 has been executed. *(not started — this plan has never been run)*
