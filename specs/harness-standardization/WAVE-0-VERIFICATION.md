# Wave 0 — verification report

**Branch:** `wave0/harness-standardization`, cut from `origin/main` @ `46521c1` (the authority
baseline). **Status: T0.1 – T0.10 complete and verified. T0.11 – T0.16 not started.**

Nothing was installed, moved, or migrated on the machine. No other repository was modified.
Wave 0 remains fully reversible: every change is a commit on this branch, and nothing has been
pushed.

## What "verified" means here

Every acceptance line in `plan/tasks.md` was *observed*, not asserted. Where an acceptance line
was a machine mutation that Wave 1 owns, it was exercised against a sandbox `$HOME` or a
disposable git repo in a temp dir instead — stated per task below.

Three test suites, **135 assertions**, all passing and all wired into `make check`:

| Suite | Covers | Assertions |
| --- | --- | --- |
| `test/install.test.sh` | T0.4 | 33 |
| `test/adopt.test.sh` | T0.5 | 32 |
| `test/workspace.test.sh` | T0.7 – T0.10 | 70 |

`make check` also validates JSON config and that all 9 hooks are executable. It previously
validated `.claude/hooks/*.sh` and would have passed silently on an empty glob; it now counts
what it checked.

## Per task

| Task | Outcome |
| --- | --- |
| **T0.1** Snapshot | 5484 files checksummed across the unique trees; 150 authored files copied and re-verified against source. `~/.claude` is a symlink to `~/agents/claude`, so T0.1's "four trees" are three unique roots. Runtime state (903 MB of transcripts) is checksummed as Wave 1's inventory but not copied — stated, not silent. `secrets.env` checksummed, never copied. |
| **T0.1a** Addendum | `~/.codex/agents/` already held all four `.toml` agents CONTRACT §9 lists as "does not exist". Authored, unversioned, outside the stated scope — the walk was widened rather than the gap left flagged. |
| **T0.2** Import ten skills | All 21 on-disk skills now have a repo copy; 59 imported files match their recorded on-machine checksums. `hot-mac`'s layer explicitly undecided. |
| **T0.3** core/ + adopt/ | Four agents as eight files; all four `.toml` parse with the required keys and their bodies were verified byte-identical to the `.md` bodies before import. No secret in `core/`. Three guards exercised from their new path. |
| **T0.4** `install.sh` | **Observed on the real machine, read-only:** `--dry-run` names exactly the two drifted skills and exits 1, and `~/.agents/` hashes identically before and after. Idempotency, refusal, reconciliation, prune, `--force`, mid-swap recovery and the secret guard exercised in a sandbox `$HOME`. |
| **T0.5** `copy.sh` | A real disposable repo is adopted and discoverable by both providers: every binding in both providers' config resolves to a file that exists, and `.agents/skills` and `.claude/skills` are the same directory. No retired surface travels; re-running clobbers nothing. |
| **T0.6** `grill` | Three skills merged into one; automatic doc creation stripped. `domain-modeling` also fixed. |
| **T0.7** `ensure-workspace.sh`, `wt` | Every CONTRACT §7 refusal case exercised; ten-run idempotency; the worktree is kept on setup failure. |
| **T0.8** Registry migration | Verified against the **real** registry read-only: source checksum unchanged, nothing written to `~/.config/`, and the diff is exactly the four `worktree_root` lines plus the `depot` block. Comments and `profiles:` survive because the transform is line-based, not a PyYAML round-trip. |
| **T0.9** Retarget skills | No shipping skill references `thoughts.md`, `.sessions/`, `.context/` or `agent_docs/`. 40 concurrent writers → 40 distinct files, 0 duplicates. `write-plan`'s automatic ADR creation removed. |
| **T0.10** Orientation hook | Writes nothing (snapshot-compared), silent when nothing resolves, filenames only — a marker written into a handoff body never reaches context. Ordering verified in a genuinely fresh worktree. |

## Decisions raised and settled during the wave

Recorded in `DECISIONS-PENDING.md` as **pass 3**, and `CONTRACT.md` reconciled to match.

- **K — hooks are repo-owned.** CONTRACT §5 could not be executed as written: it placed hooks in
  the machine payload while requiring bindings to resolve from `$(git rev-parse --show-toplevel)`,
  which only resolves if the scripts are inside the repo. Settled by the developer: a repo owns
  its hooks; machine-wide registration is deferred, and **Wave 1 T1.8 is descoped** accordingly.
- **L — the profile is single-sourced in `AGENTS.md`**, with `CLAUDE.md` a stub that imports it.

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

⚠ **Incident 2 is a live Wave 1 risk, not just a test bug.** Until T1.1 adds `.workspace/` to
`~/.config/git/ignore`, any `git add -A` in a worktree commits task memory and propagates it to
every worktree cut afterwards. T1.1 is listed as "trivial, do first" — it is load-bearing.

## Findings recorded, not acted on

- `~/.agents/skills` drift is **not staleness**: it is an in-place `CLAUDE.md`→`AGENTS.md` /
  `.claude`→`.Codex` rewrite applied to the installed projection, and it is **buggy** — the
  installed `adopt-harness/SKILL.md` documents a `.Codex/` path that does not exist. `~/.claude/skills`
  matches the repo exactly. Wave 1 T1.3 reconciles; the evidence points to repo-wins.
- `~/.claude/agents/reviewer.md` is already `model: opus` on the machine where the repo says
  `sonnet` — the projection hand-edited toward T0.12's outcome.
- The machine has an `overview-fresh-check` scheduled task for a skill CONTRACT §5 retires.

## Remaining — T0.11 to T0.16

Not started. Dependencies are satisfied; each can begin immediately.

| Task | Note for the next session |
| --- | --- |
| **T0.11** Codex hook parity | Harvest `protect-secrets.sh`'s `apply_patch` fallback from melting **`origin/main`** and record the blob SHA; do **not** harvest `95fa9b1`. The `apply_patch` matcher is already in `adopt/codex/hooks.json` and asserted by `adopt.test.sh`, but **no hook has yet been exercised against a real Codex `apply_patch` payload** — that is the substance of this task. Note this requires *reading* the melting repo; confirm that is in scope. |
| **T0.12** Reviewers | Four files: `core/{claude,codex}/agents/reviewer{,-security}.{md,toml}`. Both self-trigger sentences are still present, verbatim, in all four. `reviewer-security` → `opus`. `open-a-pr` still needs the `LOG.md`-into-PR-body change (`ship.md` already has it). |
| **T0.13** Retire old surfaces | `.claude/FLOOR.md`, the `Makefile` `work` target, `.claude/active-spec` + its `.gitignore` entry. The retired spec companions were already removed in T0.5 (T0.5's acceptance required it). `CLAUDE.template.md`'s `@.claude/FLOOR.md` import is already gone — decision L replaced that file. |
| **T0.14** Instruction files and docs | The harness's own `AGENTS.md` does not exist yet. `adopt/AGENTS.template.md` exists (written in T0.5) but T0.14 should review it. `specs/README.md` now lives at `adopt/specs/README.md`; root `specs/` holds only real specs. `agent_docs/` → `docs/` reconciliation is untouched. |
| **T0.15** Acceptance scenario | Much of it is already executable: `test/adopt.test.sh` and `test/workspace.test.sh` cover adoption and the `wt` path end to end. What is missing is the **Codex** half and the human-run scoping→spec→build→ship→remove walk. |
| **T0.16** Adversarial + security review | Explicitly requested for this wave. Give it real room — it is the review of the installer that writes the machine tree and the guards that gate every edit. |

**Wave 1 must not start until T0.16 closes.**
