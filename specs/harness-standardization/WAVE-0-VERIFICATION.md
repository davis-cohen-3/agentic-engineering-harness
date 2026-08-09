# Wave 0 — verification report

**Branch:** `wave0/harness-standardization`, cut from `origin/main` @ `92bac8e`.
**Status: T0.1 – T0.16 complete and verified. Wave 0 is closed; Wave 1 is unblocked.**

No other repository was modified. Wave 0 remains fully reversible: every change is a commit on
this branch, and nothing has been pushed.

**One machine change was made**, on the developer's instruction and out of wave order: Wave 1
T1.1 added `.workspace/` to `~/.config/git/ignore` (see *Incidents* below). Nothing else was
installed, moved, or migrated — `~/.agents/` is untouched (hashed identically before and after
every read-only probe), there is no `~/.config/agents/`, and no `~/.local/bin/wt`.

**One other repository was read, with the developer's explicit approval:** melting's `origin/main`,
read-only, to harvest the `protect-secrets.sh` `apply_patch` fallback for T0.11. No write, branch,
or commit was made there.

## What "verified" means here

Every acceptance line in `plan/tasks.md` was *observed*, not asserted. Where an acceptance line
was a machine mutation that Wave 1 owns, it was exercised against a sandbox `$HOME` or a
disposable git repo in a temp dir instead — stated per task below.

Five suites, **284 assertions**, all passing and all wired into `make check`:

| Suite | Covers | Assertions |
| --- | --- | --- |
| `test/install.test.sh` | T0.4 | 49 |
| `test/adopt.test.sh` | T0.5 | 32 |
| `test/workspace.test.sh` | T0.7 – T0.10, T0.8 shape guards | 95 |
| `test/hooks.test.sh` | T0.11, T0.16 | 56 |
| `test/contract.test.sh` | T0.12 – T0.15 | 52 |

`make check` also validates both providers' JSON config, that all 9 hooks are executable, and —
since T0.16 — that **every** `test/*.test.sh` is actually wired into `GATE_STEPS`, because a new
suite was previously silently never run.

## Per task

| Task | Outcome |
| --- | --- |
| **T0.1** Snapshot | 5484 files checksummed across the unique trees; 150 authored files copied and re-verified against source. `~/.claude` is a symlink to `~/agents/claude`, so T0.1's "four trees" are three unique roots. Runtime state (903 MB of transcripts) is checksummed as Wave 1's inventory but not copied — stated, not silent. `secrets.env` checksummed, never copied. |
| **T0.1a** Addendum | `~/.codex/agents/` already held all four `.toml` agents CONTRACT §9 lists as "does not exist". Authored, unversioned, outside the stated scope — the walk was widened rather than the gap left flagged. |
| **T0.2** Import ten skills | All 21 on-disk skills now have a repo copy; 59 imported files match their recorded on-machine checksums. `hot-mac`'s layer explicitly undecided. |
| **T0.3** core/ + adopt/ | Four agents as eight files; all four `.toml` parse with the required keys, and their bodies are asserted byte-identical to the `.md` bodies by `contract.test.sh` — no longer a one-time check. No secret in `core/`. |
| **T0.4** `install.sh` | **Observed on the real machine, read-only:** `--dry-run` exits 1 and `~/.agents/` hashes identically before and after. Idempotency, refusal, reconciliation, prune, `--force`, mid-swap recovery and the secret guard exercised in a sandbox `$HOME`. T0.16 re-measured the drift count — see *Wave 1 T1.3* below; it is **8**, not two. |
| **T0.5** `copy.sh` | A real disposable repo is adopted and discoverable by both providers: every binding in both providers' config resolves to a file that exists, and `.agents/skills` and `.claude/skills` are the same directory. No retired surface travels; re-running clobbers nothing. |
| **T0.6** `grill` | Three skills merged into one; automatic doc creation stripped. `domain-modeling` also fixed. |
| **T0.7** `ensure-workspace.sh`, `wt` | Every CONTRACT §7 refusal case exercised; ten-run idempotency; the worktree is kept on setup failure. T0.16 added two cases this missed: `wt` run **from inside a worktree**, and a **relative** `worktree_root`. |
| **T0.8** Registry migration | Verified against the **real** registry read-only: source checksum unchanged, nothing written to `~/.config/`, and the diff is exactly the four `worktree_root` lines plus the `depot` block. Comments and `profiles:` survive because the transform is line-based, not a PyYAML round-trip. |
| **T0.9** Retarget skills | No shipping skill references `thoughts.md`, `.sessions/`, `.context/` or `agent_docs/`. 40 concurrent writers → 40 distinct files, 0 duplicates. `write-plan`'s automatic ADR creation removed. |
| **T0.10** Orientation hook | Writes nothing (snapshot-compared), silent when nothing resolves, filenames only — a marker written into a handoff body never reaches context. Ordering verified in a genuinely fresh worktree. |
| **T0.11** Codex hook parity | Harvested melting `origin/main` blob `7687e47a…` (commit `4d554c16`); `95fa9b1` deliberately not harvested. Proved the gap was real by running the **pre-fix** script against Codex payloads: a `.env.local` write and a literal API key both exited 0; both exit 2 after. All seven repo-owned hooks exercised against both providers' payload shapes from a real adopted repo; path resolution verified from a deep subdirectory, including one hook invoked **through** its Codex binding. ⚠ T0.16 then found the payload model incomplete — see S1 below. |
| **T0.12** Reviewers and shipping | Both self-trigger sentences gone from all four files; each description states it runs only on request; `reviewer-security` → `opus`. The Codex `.toml` adapter carries no `model` key for any agent, so that move is Claude-only — an asymmetry recorded rather than papered over with an unverified format key. `open-a-pr` owns the `LOG.md` carry; `ship` delegates. |
| **T0.13** Retire old surfaces | `FLOOR.md` removed and its content redistributed per DECISION I (the gate **retained**); `work` target and `install-global` removed with tombstones. ⚠ The `.claude/active-spec` half was **done wrong and caught by T0.16** — see C1. |
| **T0.14** Instruction files and docs | `AGENTS.md` is the single profile, `CLAUDE.md` a seven-line stub. `agent_docs/` retired into `adopt/docs/` (and now travels, write-only-when-absent). Planning artifacts moved under the epic. Two real gaps found by the new assertions: `prototype` and `research` had no `STARTER_CHARACTER`, and `PLAN-MODE.md` still routed output to `thoughts.md`. |
| **T0.15** Acceptance scenario | 40 steps across 11 phases; every CONTRACT §7 claim mapped, every step carries an observable. Internal completeness is itself gate-asserted — verified by injecting three failure shapes and watching each fail. T0.16 found Depot unexercised and added steps C4–C5. |
| **T0.16** Adversarial + security review | Both reviewers run. **One critical security bypass, one high-severity contract violation, three must-fix correctness bugs, six hollow assertions** — all fixed with mutation-tested guards. The eight initially accepted findings were then walked one by one with the developer: **six were fixed after all**, three stand by explicit decision. Full record: [`T0.16-REVIEW.md`](./T0.16-REVIEW.md). |

## What T0.16 changed about the earlier tasks

Three of the ten "verified" tasks had defects that survived their own acceptance checks. Recorded
here because a verification report that only lists successes is not a verification report.

- **S1 (critical).** `protect-secrets.sh` never path-checked a `*** Move to:` rename destination,
  so a Codex agent could write a benign file and rename it onto `.env`. T0.11's payload model was
  built from 118 *observed* payloads, none of which was a rename — **observed traffic is not the
  grammar**. Confirmed against the `codex 0.147.0` binary, which carries all four directives.
  Melting's `origin/main` has the same gap. A verified patch for it is at
  `patches/melting-protect-secrets-move-to.patch`; applying it is the developer's action.
- **C1.** T0.13 removed `.claude/active-spec` from `.gitignore` but not from disk, so the next
  `git add -A` **committed** the retired surface. The commit message claimed otherwise.
- **C2.** The Stop gate never fired in this repo: it grepped for `^check:` in a `Makefile` that
  only `include`s another one. `make check` being green never proved the hook enforced it.

## Two incidents, both closed

1. **The T0.7 test cut two real worktrees.** It invoked `wt` without `cd`-ing into its sandbox, so
   `wt` resolved this repo, found it in the real registry, and created
   `~/workspaces/harness/{thing,taken}` plus their branches. Both were at `origin/main` with no
   commits and no uncommitted work. Exactly those two were removed and the two pre-existing
   worktrees verified intact. The test now pins `XDG_CONFIG_HOME` **and** cwd into the sandbox.
2. **The T0.10 test committed `.workspace/`.** Its own `git add -A` tracked the directory, so every
   new worktree inherited another worktree's task memory from `origin/main`. The sandbox now
   models the real mechanism — exclusion via a *global* gitignore, no repo `.gitignore` involved —
   and asserts `.workspace/` is neither tracked nor visible to git.

✅ **Incident 2 is closed at the source.** It was a live risk, not just a test bug: until
`.workspace/` was globally ignored, any `git add -A` in a worktree committed task memory and
propagated it to every worktree cut afterwards.

**A third, latent instance of incident 1 was found in T0.16 and closed:** `test/install.test.sh`
pinned `HOME` but not `XDG_CONFIG_HOME`, so on any machine that sets it the sandboxed test would
have written the real `~/.config/agents/projects.yaml`. Dormant here only because the variable is
unset.

**Wave 1 T1.1 was pulled forward and executed on 2026-08-09** on the developer's instruction —
the one machine change made during Wave 0. `~/.config/git/ignore` gained `.workspace/`. Verified
empirically in a fresh repo: `MISSION.md`, `LOG.md` and `history/` records are all ignored,
`git status -uall` is clean, and `git add -A` followed by `git ls-files` lists nothing. The
pre-existing `**/.claude/settings.local.json` entry still matches. `core.excludesFile` is unset, so
git uses this path by documented default — confirmed live before editing. Backup:
`~/.config/git/ignore.pre-workspace.bak`. Reversible by restoring it.

## Findings recorded, not acted on

- `~/.agents/skills` drift is **not staleness**: it is an in-place `CLAUDE.md`→`AGENTS.md` /
  `.claude`→`.Codex` rewrite applied to the installed projection, and it is **buggy** — the
  installed `adopt-harness/SKILL.md` documents a `.Codex/` path that does not exist.
  `~/.claude/skills` matches the repo exactly. Wave 1 T1.3 reconciles; the evidence points to
  repo-wins.
- `~/.claude/agents/reviewer.md` was already `model: opus` on the machine where the repo said
  `sonnet` — the projection hand-edited toward T0.12's outcome, which T0.12 has since made real.
- The machine has an `overview-fresh-check` scheduled task for a skill CONTRACT §5 retires.

## Wave 1 T1.3 — measured, not predicted

`plan/tasks.md` now carries the measured list. Summary: `--dry-run` refuses **8** files (six are
Wave 0's own rewrites, which `install.sh` cannot distinguish from hand-edits without a manifest —
refusing is correct), and reports `keep 4` including `grill-me` and `overview-fresh`, both retired
by CONTRACT §5. **T1.3 must run `--prune`**, or T0.6's grill collapse never reaches the machine.

---

## Starting the next session

Read, in this order: `DECISIONS-PENDING.md` → `CONTRACT.md` → `plan/tasks.md` → this file →
`T0.16-REVIEW.md`. Then begin **Wave 1**. Everything in Wave 0 is settled — do not reopen it.

**Branch:** `wave0/harness-standardization`, 20 commits, nothing pushed. `make check` is green
and runs all 284 assertions.

**Structure** (the plan's older files describe the pre-restructure layout):

```text
core/     → ~/.agents/ via install.sh   skills/ rules/ claude/agents/ codex/agents/
                                        hooks/ holds ONLY inject-global-rules.sh
adopt/    → a target repo via copy.sh   AGENTS.template.md CLAUDE.template.md hooks/
                                        settings.json codex/hooks.json Makefile make/ specs/ docs/
packs/    → versioned, installed nowhere: project/ area/ retired/ unassigned/
bin/      → wt, workspace-record        install/ → migrate-registry.py
test/     → install adopt workspace hooks contract
.claude/ + .codex/ → this repo's own project layer and its two hook bindings
```

**Three decisions are settled and confirmed by the developer** — treat as authority alongside the
baseline:

- **K** — a repo owns its own hooks. Machine-wide safety-hook registration is deferred; Wave 1
  T1.8 is descoped to `inject-global-rules.sh`. Re-confirmed 2026-08-09.
- **L** — `AGENTS.md` is the single profile; `CLAUDE.md` is a stub that `@AGENTS.md`.
  Re-confirmed 2026-08-09.
- **T1.1 is done** — `.workspace/` is globally ignored.

**Three habits this wave earned the hard way**, all now enforced by tests:

1. Any test that invokes `wt` must pin **both** `XDG_CONFIG_HOME` and cwd into its sandbox.
   Without both, `wt` resolves the real registry and cuts real worktrees in real projects. The
   same applies to anything reading `${XDG_CONFIG_HOME:-$HOME/.config}` — pinning `HOME` alone is
   not enough.
2. Never `git add -A` in a sandbox repo that has a `.workspace/` unless the sandbox also models
   the global gitignore.
3. **A guard is not verified until you have watched its test fail.** Three defects in this wave
   sat behind assertions that could not fail: a whole-file grep satisfied by the wrong line, a
   `grep -r` over a path that no longer existed, and a completeness check asserted against its own
   fixture. Mutate the thing the assertion protects, watch it go red, then restore.
