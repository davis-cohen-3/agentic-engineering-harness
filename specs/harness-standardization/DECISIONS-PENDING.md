# Settled decisions — harness standardization

**Status:** ✅ **Closed**, plus a **pass 3** of amendments raised while executing Wave 0 and a
**pass 4** settled while reviewing the closed wave before any machine step. This file is
the **authority** for intent; `CONTRACT.md` and the design review are reconciled *from* it.
**Settled:** 2026-08-07 (pass 1, DEC-1…15), 2026-08-08 (pass 2, A–J), 2026-08-08 (pass 3, K–L),
2026-08-09 (pass 4, M–P).
**Implementation posture:** Wave 0 is complete and verified (`WAVE-0-VERIFICATION.md`). The machine
is untouched except Wave 1 T1.1 (`.workspace/` in the global gitignore, pulled forward on the
developer's instruction); no other repository has been touched.

## Authority order

1. **This file** — the decisions, and the verified facts behind them.
2. **`CONTRACT.md`** — the operating model, reconciled against this file.
3. **`HARNESS-DEPOT-OPERATIONAL-DESIGN-REVIEW.md`** — DEC-1…15 evidence and provenance.
4. **`plan/tasks.md`** — the execution plan.
5. **`PRE-IMPLEMENTATION-CONTRACT-AUDIT.md`** — historical; superseded wherever this file differs.
6. **`01-*.md` … `08-*.md`** — legacy, superseded, not executable.

Where any two disagree, the higher entry wins.

---

## Verified machine facts

Everything below was checked directly on this machine on 2026-08-08. Two review passes each
asserted things that turned out to be false; these are the survivors.

| Fact | Value |
| --- | --- |
| Claude CLI version | **2.1.226** (five `2.1.22x` installed). *Not* 2.0.73. |
| `WorktreeCreate` hook | **exists** — `WorktreeCreateHook`, listed with `PreToolUse`/`SessionStart` |
| Claude worktree default | `<repo>/.claude/worktrees/<name>`; settings expose `baseRef`, `bgIsolation` |
| Codex worktree default | `~/.codex/worktrees/<hash>/<repo>` |
| Secondary worktrees | **101** — melting-v2 26, smoke-screen 66, depot 7, harness 2 |
| Worktree root families | 6 — Claude, nested Claude, Codex, `.worktrees`, `~/workspaces`, `~/.paseo` (prunable) |
| Depot registry | **`~/.config/depot/projects.yaml` EXISTS** — 4 projects: smoke-screen, melting-v1, melting-v2, harness. `depot` itself unregistered. Carries `setup_cmd`/`archive_cmd` (old model). |
| `~/.config/agents/projects.toml` | does not exist |
| Parsers | `jq` `/usr/bin/jq`; `python3` 3.12.6 with **`tomllib`** and **PyYAML 6.0.3**. `yq`, `tomlq`, `dasel` absent. |
| Skill counts | `~/.agents/skills` 11 · `~/.codex/skills` 9 · `~/.claude/skills` 20 · tracked in harness 11 |
| Unversioned skills | **10** — domain-modeling, grill-with-docs, grilling, hatch-pet, hot-mac, prototype, research, setup-matt-pocock-skills, teach, wayfinder |
| `~/.agents/skills` drift | **already drifted** — `adopt-harness/SKILL.md` and `docs-drift/SKILL.md` differ from the repo |
| `~/.claude` | symlink → `~/agents/claude` (not a git repo) |
| melting `origin/main` Codex hooks | **already carry the fix** — `apply_patch` fallback parser in `protect-secrets.sh`, `matcher: "Read\|Edit\|Write\|apply_patch"` |
| Commit `95fa9b1` | **not** on `origin/main` — only `origin/agent/codex-hook-matcher`. It removes `apply_patch` from the comment-bloat matcher. |
| Project Codex hooks | depot and smoke-screen register all six (absolute paths); melting uses relative `../.claude/hooks/…` |
| Machine Codex hooks | only `inject-global-rules.sh` |
| Codex hook trust | per-hash — `~/.codex/config.toml [hooks.state] trusted_hash = "sha256:…"` |
| Automatic PR review | smoke-screen only (`pull_request: [opened, synchronize, closed]`, job at `claude-code.yml:152`, needs a GitHub App + 4 secrets). melting is `@claude`-mention only. depot and harness have none. |
| Branch protection | melting and agentic-engineering `main` unprotected; smoke requires Build/Lint/Test, **0 approvals**, reviewer not a required check |
| `~/.config/git/ignore` | contains only `**/.claude/settings.local.json` |
| `~/.config/agents/secrets.env` | does not exist; `~/.claude/secrets.env` exists, mode 600 |
| `/simplify` | bundled and present in the installed version |
| LSP plugins | **none installed** (only `frontend-design` enabled) |
| E2E | no harness skill; smoke-screen has `e2e-test` + `e2e-after-push.sh` |
| `make setup` per repo | melting `npm ci` · smoke `npm ci` · depot `uv sync` + web-deps · harness unset (no-op) |
| melting `specs/build-week/` | on `origin/main`, tasks 00–19+, six worktrees building from it |

**Documented by current official sources, but not locally acceptance-tested.** These are untested
dependencies, not assumptions — Wave 1 tests each, and each has a safe fallback:

- Codex resolves hook commands from the session cwd (so melting's `../.claude/hooks/…` bindings are
  unsafe; resolve from `$(git rev-parse --show-toplevel)` instead);
- Codex treats `Edit` and `Write` as matcher aliases for `apply_patch` (so `Write|Edit` does **not**
  exclude patch payloads);
- the Claude Desktop worktree-location setting;
- Codex Settings → Worktrees → Worktree root;
- provider automatic cleanup on archive/retention.

Codex has **no documented `WorktreeCreate`-equivalent hook**. That is a statement about the
documentation, not proof of absence.

**Corrections issued to prior documents.** Pass 1 wrongly claimed the Depot registry did not exist
and that provider worktree locations were not configurable. Pass 2 wrongly claimed the Claude CLI
was 2.0.73, that no TOML parser was available, and that melting's `origin/main` lacked the Codex
fix. Pass 1's "nine unversioned skills" was an undercount; the answer is ten.

---

## Pass 1 — the operating model (DEC-1 … DEC-15)

Settled 2026-08-07. Full evidence and rationale in the design review's **Resolved decisions**.
Amendments from pass 2 are marked.

| # | Decision | Pass-2 status |
| --- | --- | --- |
| DEC-1 | Depot is an operational cockpit only; the harness owns `.workspace/` | unchanged |
| DEC-2 | Ownership of creation, setup, init, orientation, removal; lazy SessionStart init | **amended by B** — five creation paths, eager init via `WorktreeCreate` |
| DEC-3 | `.workspace/` schema: `MISSION.md`, `LOG.md`, flat `history/`, `artifacts/` | unchanged |
| DEC-4 | `MISSION.md` schema, four states, two obligations, lossy by design | **amended by D** — obligations gain owners |
| DEC-5 | No scoping document; `LOG.md` → spec | unchanged |
| DEC-6 | The spec pointer is one field; the binding apparatus is deleted | unchanged |
| DEC-7 | No concurrency protocol | **amended by J** — "cannot collide" holds only given atomic creation |
| DEC-8 | No enforcement machinery; promotion is a conversation at merge | unchanged |
| DEC-9 | `~/.agents/` canonical; `~/agents/` retired; secrets at `~/.config/agents/secrets.env` | unchanged |
| DEC-10 | Layering decided by portability, not frequency | unchanged |
| DEC-11 | The skill and agent catalog; the grill collapse | **amended by G** — E2E removed, `hot-mac` needs a layer |
| DEC-12 | Provider parity, hooks, plugins, LSP, security-review model | **amended by E and G** — LSP claim struck, security trigger removed |
| DEC-13 | One documentation namespace; planning artifacts live with their epic | unchanged |
| DEC-14 | Two mandatory local steps; review lives on the PR | **superseded by E** — no mandatory review at all |
| DEC-15 | The day-to-day journey; `.workspace/` excluded via global gitignore | **amended by H** — the default journey is three steps |

---

## Pass 2 — the ten blocking decisions (A … J)

### A — Canonical registry and parser

**Canonical: `~/.config/agents/projects.yaml`**, created by promoting the existing
`~/.config/depot/projects.yaml`. Same file, same format, new path. No second catalog.

- **YAML, not TOML.** Depot parses it natively and it already holds the real data.
- **`wt` reads it via a one-line `python3 -c`.** No new machine dependency — Depot already requires
  Python. Rejected JSON+jq (poor to hand-edit, needs a new Depot reader) and TOML (converts existing
  data for no gain).
- **Depot's cutover moves to Wave 2**, not Wave 3 — it is a path constant, not a feature.
- **Migration edits:** rewrite the four `worktree_root` values to the new layout; add the missing
  `depot` project.

### B — Worktree topology and lifecycle

**Unify on the managed root: three creators, one location, eager init.**

- Both providers are configured to write into `<container>/worktrees/` (Claude Desktop
  worktree-location setting; Codex Settings → Worktrees → Worktree root).
- **`WorktreeCreate` runs `ensure-workspace.sh` + `make setup`**, so provider-created worktrees get
  the same three jobs `wt` does, eagerly.
- **`ensure-workspace.sh` on SessionStart remains the net** for plain `git worktree add`, for a
  setting that did not take, and for any path not yet known. Still the invariant — no longer the
  only mechanism.
- **Depot discovery becomes meaningful**: it sees only direct children of its root, today 1 of
  melting-v2's 26.
- **Safe degradation:** if a GUI setting does not exist, that provider keeps its own root and the
  SessionStart net still covers it.

**Layout — `worktrees/` is a peer of the container, not the business root.** `~/melting` and
`~/smoke` are business roots (`code`, `comms`, `docs`, `finance`, `ops`):

```text
~/melting/code/melting-v2/     checkout — tracks origin/main, not worked in
~/melting/code/worktrees/<b>
~/smoke/code/smoke-screen/
~/smoke/code/worktrees/<b>     already exists with 3
~/dev/depot/
~/dev/agentic-engineering/
~/dev/worktrees/<repo>/<b>
```

**No repository moves required.** `~/smoke/code/smoke-worktrees/` (1 worktree) folds into
`worktrees/`; `~/melting/code/melting-v2/worktrees/` holds only a stray nested `.claude/worktrees/`
and is cleaned up.

**`code/` is a reference checkout** tracking `origin/main`; all work happens in worktrees. This is a
**change of practice** — melting-v2, depot, and agentic-engineering are currently on task branches
and all four checkouts are dirty.

**`wt` contract.** `wt <project> --branch <b>`: resolve via the registry, or via
`git rev-parse --show-toplevel` when run inside a repo → `git fetch origin` → create the worktree at
`<container>/worktrees/<b>` branching from **`origin/main`** → create `.workspace/` → `make setup`
unless `--no-setup`.

- **No `--base` flag.** `origin/main` is absolute. The spec must be **merged**, not merely
  committed, before parallel build worktrees are cut — which is already the observed practice.
- **Branch names with slashes** → the directory is the **last path segment**
  (`claude/w1-17-task-model` → `w1-17-task-model`).
- **Branch or directory already exists** → refuse, non-zero exit, print the existing path.
- **Setup fails** → keep the worktree, report loudly, exit non-zero. No rollback; `make setup` is
  re-runnable.
- **No Makefile, or no `setup` target** → skip silently and say so.
- **Not a Git repo, or no `origin`** → refuse with the reason.
- **Unadopted repo** → proceed; `.workspace/` does not require adoption.
- **Version floor:** none. `install.sh` verifies `WorktreeCreate` and the location settings rather
  than asserting a version.

### C — Orientation

**No standalone `orient` skill.** The read-only SessionStart hook surfaces the rest.

`spec-session-orient.sh` is rewritten in Wave 0 anyway (DEC-6: read `MISSION.md`'s `spec:` field
instead of `.claude/active-spec`, drop the self-bind write). It additionally prints:

- `MISSION.md` — `state` and `## Next action`;
- the spec path;
- the newest `history/*-handoff-*.md` **filename**;
- the `history/*-finding-*` **filenames**;
- brief `git status`.

**Filenames only, never contents.** Read-only, fails open, silent when nothing resolves.

### D — `MISSION.md` write owners

Two obligations, not two moments. Initialization is not an agent write. "At session end" is dropped
— a SessionEnd hook can fire after the model can no longer act.

| Write | Owner |
| --- | --- |
| Create the file | `ensure-workspace.sh` / `WorktreeCreate` |
| `state: building` + `spec:` | **`write-plan`**, as it writes the spec |
| Sync before a history record | **`handoff`**, immediately before writing |
| Final position, `state: shipped` | **`/ship`** or an explicit close |
| `state: abandoned` | explicit close only |
| After an abrupt end | nothing — staleness accepted; SessionStart recovers read-only |

Each obligation rides an action the agent already chose to take, so detection costs nothing.
**Intended consequence:** a session that scopes without producing a spec never leaves `scoping`.

### E — Review coverage: nothing runs unless asked

- **No reviewer runs automatically, ever.** Not during building, not at `/ship`.
- **Both agents lose their self-trigger descriptions** — `reviewer-security.md` ("Trigger whenever
  the diff hits a hotspot, even a one-liner") and `reviewer.md` ("Trigger after an implementation is
  'done' and before /ship"). Those lines are the mechanism, not a policy note elsewhere.
- **`/ship` gains no coverage logic.** Explicitly deferred; add later if it proves uncomfortable.
- **PR review is a declaration only.** A project records whether it has an automatic bot. **Nothing
  consumes it** — documentation, not behaviour.
- **`reviewer-security` still moves to `opus`.** DEC-12's "bounded because it only runs on hotspots"
  no longer applies, but rare and deliberate invocation is exactly when the strongest model is worth
  it.

**Accepted exposure:** nothing blocks a merge in any repo. Sensitive changes can ship with no
adversarial pass. Deliberate, and owned by the developer.

### F — Cleanup is owned by the creator

| Creator | Removal |
| --- | --- |
| `wt`, Depot | Depot's guarded trash |
| Claude | its own cleanup on exit/archive, plus the temporary sweep |
| Codex | its own cleanup on archive/retention, which saves snapshots |
| plain `git worktree add` | manual |

**Provider automatic cleanup stays enabled** — 101 worktrees already exist, so the sweeps are not
keeping up as it is.

**Pass 1's "cleanup is manual through Depot; no automatic removal exists" is struck as false.**
Automatic removal exists in both providers, and decision B has pointed both into the managed root,
so provider sweeps now operate where Depot also believes it has authority.

**Accepted loss, widened:** a retention sweep can remove a worktree that was never explicitly
retired, taking `LOG.md` with it. The only mitigation is unchanged — **the PR body is the bridge.**

### G — Provider capability policy

1. **No version floor.** `install.sh` verifies capabilities and reports what is missing.
2. **`/simplify`:** use the builtin, vendor nothing. No Codex equivalent is invented.
3. **E2E is removed from the harness contract.** It fails the portability test. smoke-screen keeps
   its own. Leaves Wave 0 rather than gaining an invocation contract.
4. **The LSP claim is struck.** No LSP plugin is installed. LSP becomes a per-project area-pack
   adoption check; Codex LSP equivalence is explicitly unassigned.
5. **Codex plugin scoping:** untested, not an exception. Experiment runs in a **disposable** trusted
   repo.

### H — The journey, kept small

**Default (T0–T2), which is most work:**

```text
wt <project> --branch <b>   →   build   →   ship
```

No spec, no planning worktree, no transition. CONTRACT §7's twelve-step sequence must stop being
presented as *the* journey.

**T3 only**, because parallel worktrees need the spec on `origin/main`:

```text
1  wt <project> --branch plan/<slug>    planning worktree, off origin/main
2  brainstorm → grill                   → .workspace/LOG.md
3  write-plan                           → specs/<epic>/README.md + 01-*.md
                                          sets MISSION state:building, spec:
4  spec-only PR → merge to main
5  wt <project> --branch <task-N>  × N  each cut fresh from origin/main
6  each MISSION's spec: field → the same spec path
7  build in parallel
```

"Bind" is not vocabulary — step 6 edits a field. Planning gets its own worktree, because `code/` is
a reference checkout.

### I — Installer, adopter, and instruction files

**Frame:** the harness repo is the versioned source; `~/.agents/` is an installed projection, never
edited in place.

```text
core/                      → ~/.agents/
  skills/                  shared; both providers read SKILL.md
  hooks/                   shared; one script, two bindings
  rules/                   injected by inject-global-rules.sh
  claude/agents/           4 × .md + frontmatter
  codex/agents/            4 × .toml + developer_instructions

adopt/                     → copied into a target repo
  CLAUDE.template.md
  AGENTS.template.md       DOES NOT EXIST — why adopted repos come out Claude-only
  Makefile, make/, specs/
```

The two logical reviewer rewrites touch **four** files.

**`install.sh`:** temp tree then swap; one backup (`~/.agents.prev`); idempotent; **prune is opt-in**
(`--prune`) because `~/.agents/skills` has already drifted; **manual edits refuse the run**, naming
the file; `--dry-run`; migrates the registry only when the target is absent; installs `wt` to
`~/.local/bin/`.

**Expected:** the manual-edit check fires on first run against the two already-drifted skills. First
`install.sh` is a two-step on this machine, by design.

**Machine-level instruction files: keep the injection hook.** `~/.claude/CLAUDE.md` is not created;
`~/.codex/AGENTS.md` stays empty. Rules stay `core/rules/*.md` delivered by
`inject-global-rules.sh`, **including its suppression inside any repo owning `.claude/` or
`CLAUDE.md`**. The legacy proposal to go native is rejected — it would load personal preferences in
every project, reversing a deliberate choice.

**The harness repo needs its own `AGENTS.md`.** It is the only one of the four repos without one.

**`.claude/FLOOR.md` is removed.** Content disposition — corrected, because the table in
`specs/harness-standardization/README.md` assumed a legacy plan that deleted the quality gate:

| FLOOR content | New home |
| --- | --- |
| task branch · ship via PR · minimal comments · match idiom | already verbatim in `core/rules/00-preferences.md` — no action |
| Definition of done | `verify-before-done/SKILL.md` |
| Two modes · T0–T3 tiers · one-run-one-task | `specs/README.md` + the plan/build skills |
| Spec binding (`make work SPEC=`, self-bind) | **deleted** — DEC-6 |
| Risk hotspots | the project's own `AGENTS.md` |
| Skill markers | each `SKILL.md` already declares `STARTER_CHARACTER` — no action |
| `make check` is the gate | **CORRECTED: retained.** Belongs in the project's `AGENTS.md` and CONTRACT §6 |

⚠ **`CLAUDE.template.md:7` is `@.claude/FLOOR.md`** and decision B drops FLOOR from the manifest.
Fix in the same wave or the template imports a file that no longer travels.

### J — History write protocol

- Timestamps stay readable: `YYYYMMDDTHHMMSSZ`, e.g. `20260808T143000Z-handoff-wt-command.md`.
- **Creation is atomic** — `set -o noclobber` / `O_EXCL`. If the file exists the create *fails*; the
  writer retries `-2`, `-3`. Check-then-write is a race and is rejected.
- **`artifacts/` is write-once**, created the same atomic way. An immutable `history/` record must
  never come to reference mutated evidence.

DEC-7's "records cannot collide" is true **only given this rule**, and must be stated that way.

---

---

## Contradiction pass — 2026-08-08

Every decision was checked against every other and against the full journey. Retired vocabulary
(`thoughts.md`, `scoping.md`, `active-spec`, `agent_docs/`, `depot workspace`, `workspace_id`,
`make work`, `{path, commit}`, bare `~/agents/`) appears in the authoritative documents **only**
inside retirement tables, removal instructions, and statements of current fact. No live use.

Four issues were found and all four are now fixed:

| # | Issue | Resolution |
| --- | --- | --- |
| 1 | **D vs H — an unowned write.** D assigns `spec:` to `write-plan`, but in a T3 the N build worktrees are cut *after* `write-plan` ran in the planning worktree, so nothing sets their `spec:`. | CONTRACT §2 gains a row: the developer or first session sets it manually at §7 step 6. It is the only `MISSION.md` write with no automated owner, and it says so. |
| 2 | **Hook order was unstated.** Orientation reads what the initializer creates, so `ensure-workspace.sh` must be registered *before* `spec-session-orient.sh`. Reversed, the first session in a fresh worktree orients against nothing. | Stated in CONTRACT §7 and in task T0.10's acceptance, which now requires verification in a brand-new worktree. |
| 3 | **B's eager init is Claude-only.** Codex has no `WorktreeCreate` equivalent, so Codex-created worktrees stay lazy. | Stated in CONTRACT §7 as an accepted asymmetry, with the observable difference named. |
| 4 | E2E still appeared in the catalog's Project row after G removed it. | Removed. |

**Accepted overlaps, not contradictions:**

- Provider cleanup sweeps now operate inside the managed root where Depot also has authority (B × F).
  Both documents say so.
- `make check` still auto-runs via `enforce-gate-on-stop.sh` under a "nothing runs automatically"
  review policy. The gate is not a review; E constrains reviewers only.
- `code/` as a reference checkout contradicts current practice, not the contract. Flagged as a
  change of practice in CONTRACT §11.

---

## Pass 3 — amendments raised during implementation

Decisions taken **after** the baseline was committed, because executing Wave 0 surfaced a
contradiction the two earlier passes did not. Recorded here rather than absorbed silently: this
file is the authority, so an amendment that lives only in code is the failure this epic exists to
fix.

**Both were re-confirmed by the developer on 2026-08-09**, after the implementation existed:
K ("repos do own their own hooks") and L ("AGENTS.md is the single profile, CLAUDE.md imports
it"). They are settled, not provisional.

### K — Hooks are repo-owned; machine-wide hook registration is deferred

**Raised at T0.5.** `CONTRACT.md` §5 could not be executed as written. Two of its statements do
not compose:

- `core/hooks/` is part of the **machine** payload, and the six safety hooks "must be registered in
  `~/.codex/hooks.json` — this is a **machine-level** gap only";
- yet "hook command paths resolve from `$(git rev-parse --show-toplevel)`", with absolute machine
  paths explicitly rejected as breaking on a repository move.

`$(git rev-parse --show-toplevel)` only resolves to a real script if the scripts are **inside the
repo**, so hooks cannot be both machine-installed and bound that way.

**Settled 2026-08-08 by the developer: a project/repo owns its own hooks.** Machine-wide
registration is a *maybe later*, explicitly not configured now.

| | Disposition |
| --- | --- |
| The seven repo-level hooks | `adopt/hooks/` → `<target>/.claude/hooks/`, bound by both providers |
| `inject-global-rules.sh` | stays in `core/hooks/` — it exists to inject personal rules **outside** projects and suppresses itself inside any repo owning `.claude/` or `CLAUDE.md`, so it is the one hook that is genuinely machine-level |
| Claude binding | `adopt/settings.json` → `<target>/.claude/settings.json`, `$CLAUDE_PROJECT_DIR`-relative |
| Codex binding | `adopt/codex/hooks.json` → `<target>/.codex/hooks.json`, resolved from `$(git rev-parse --show-toplevel)` |
| Machine-wide safety hooks | **deferred** — Wave 1 T1.8 is descoped to `inject-global-rules.sh` |

**Consequence, accepted:** the scripts are copied per repo, so a hook fix must be re-adopted into
each repo rather than installed once. The compensating property is that a clone carries its own
guardrails and does not depend on the machine having been provisioned.

**"One script, two bindings" still holds** — it just means one copy *per repo* read by both
providers, not one copy per machine.

### L — The repo profile is single-sourced in `AGENTS.md`

**Raised at T0.5**, which requires an adopted repo to be discoverable by both providers.
`AGENTS.template.md` had no specified content, and the obvious shape — a second copy of
`CLAUDE.template.md`'s profile — creates exactly the duplication this repo's central discipline
forbids.

**`AGENTS.md` is the profile; `CLAUDE.md` is a stub that `@AGENTS.md`.** Codex reads `AGENTS.md`
natively and Claude follows the import, so every fact is written once. Claude-only guidance goes
below the import.

---

## Pass 4 — Wave 1 split and the sync channels

Settled 2026-08-09 with the developer, in a review session between the close of Wave 0 and any
machine step. Raised because Wave 1 as planned conflated two different projects, and because
thinking through day-to-day use surfaced two missing sync channels in the single-source model.

### M — Wave 1 splits: activation now; machine cleanup deferred, unscheduled

The old Wave 1 bundled two things:

- **Activation** — upgrade the already-installed `~/.agents/` to the repo (the machine runs a
  drifted version N−1 today), add `wt`, the registry, provider configuration, and point the
  provider skill/agent subdirectories at `~/.agents/`. Additive, or an in-place upgrade of
  harness-owned territory. Touches **no live runtime state**.
- **Cleanup** — undo the `~/.claude` symlink, move ~903 MB of live Claude runtime state, delete
  `~/agents/`. Pure hygiene: its value is eliminating the `~/agents` vs `~/.agents`
  one-character hazard and the two-hop symlink topology. The **entire** runtime-state risk of
  the wave lives here, and the harness functions without it.

**Settled: they split.** Wave 1a is the activation and runs next. Wave 1b is the cleanup,
**deferred unscheduled** — it runs only on an explicit later decision, with a rehearsed
manifest-driven script and a non-Claude operator, or never.

- **T1.2 (secrets) moves into 1a.** `secrets.env` currently sits inside `~/agents/claude/` — a
  tree whose siblings are authored rules Wave 0 imported into a git repo. That violates §5's
  governing invariant *today*, and the fix touches zero runtime state and is reversible at every
  step. It is the one cleanup-class risk that is live rather than hypothetical.
- **The provider subdir symlinks move into 1a** (task T1.4a): without them Claude keeps reading
  `~/agents/claude/skills` and the machine never converges. They are laid **through the existing
  topology** (`~/agents/claude/skills` itself becomes the symlink); displaced real directories
  are moved aside, never deleted.
- **Consequence, accepted:** until 1b runs — if ever — `~/agents/` lives on, the one-character
  hazard stands, and CONTRACT §5's "`~/agents/` is retired" is a target state, not a fact.
- **A fresh machine never needs 1b.** It has no legacy trees. Second-machine adoption is
  clone + `install.sh` + per-machine facts (registry, secrets, provider settings) — the same
  path the install sandbox already exercises.

### N — `install.sh --review`: the inbound channel; prune never runs blind

The single-source model needs its two sync channels made visible. Inbound (machine → repo):

- `install.sh` gains `--review`: every extra (`keep`) and every drift (refusal) presented as an
  inbox with a per-file disposition — **import** (copy into the repo working tree, ship by PR),
  **prune**, or **leave**.
- `--review` also lists, read-only, what sits in the non-symlinked provider locations
  (`~/.claude/plugins/`, other provider surfaces), so provider-shipped novelties are visible.
  Judging a genuinely *new kind* of surface stays human — observed traffic is not the grammar.
- **Standing rule: `--prune` never runs blind.** A review pass precedes it, always.
- Anti-bloat: a flag on `install.sh`, not a new tool or skill.

### O — Adoption is the update channel; `copy.sh` stamps the harness version

Outbound (repo → adopted repos). Decision K's accepted consequence — hook scripts are copied per
repo, so a fix must be re-adopted into each — gets its mitigation:

- `copy.sh` records the harness source commit in the adopted repo; a check compares the stamp to
  the harness repo and reports staleness ("melting is N commits behind").
- **Re-running adoption is the supported upgrade path** — safe by construction, because
  scaffolding copies unconditionally and fills are write-only-when-absent.
- The live demonstration of the failure this closes: melting's `protect-secrets.sh` fork carries
  the S1 CRITICAL gap while the repo's copy is fixed.

### P — MCP configuration is out of the harness's scope

Per-repo MCP config (`.mcp.json` and provider equivalents) stays **provider-native, owned by
each repo**. The harness neither templates, copies, nor manages it; `adopt-harness` does not
prompt for it. Recorded so the absence is a decision, not an omission. Revisit only if per-repo
MCP drift becomes a demonstrated pain.

---

## Open, deliberately deferred

| Item | Why deferred |
| --- | --- |
| Wave 1b — machine cleanup (T1.4b: undo the `~/.claude` symlink, move the runtime state; T1.5: retire `~/agents/`) | deferred **unscheduled** by M; if it ever runs it needs a rehearsed manifest-driven script and a non-Claude operator. A fresh machine never needs it |
| `hot-mac` layer or retirement | unique unversioned source; preserve first, decide later |
| Depot `post_create_cmd` | additive, non-blocking; own Depot spec |
| Codex PR-review equivalent | no requirement under E |
| `/ship` review-coverage logic | E defers it explicitly |
| Codex LSP equivalence | unassigned under G |
| melting-v2 per-file docs merge | needs human judgement per file |
