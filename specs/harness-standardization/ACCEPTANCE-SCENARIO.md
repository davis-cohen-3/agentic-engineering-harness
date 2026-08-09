# Acceptance scenario — the two-provider end-to-end walk

**Run by:** Wave 2 (T2.4), after Wave 1 has configured the machine.
**Authority:** [`DECISIONS-PENDING.md`](./DECISIONS-PENDING.md) → [`CONTRACT.md`](./CONTRACT.md) →
[`HARNESS-DEPOT-OPERATIONAL-DESIGN-REVIEW.md`](./HARNESS-DEPOT-OPERATIONAL-DESIGN-REVIEW.md) →
[`plan/tasks.md`](./plan/tasks.md). Where any two disagree, the higher wins.

This is the scenario that proves the operating model works on a real machine with real providers.
Every step has an **observable** — a thing you look at, not a thing you assume. A step whose
observable you did not see is a step that did not pass.

Wave 0 already automates the mechanical half; this document says which steps those are, so Wave 2
runs the machine- and provider-dependent remainder rather than re-doing work.

---

## Safety rules — read before running anything

1. ⚠ **`wt` cuts real worktrees in real projects.** Any invocation outside the disposable repo —
   including from a test — must pin **both** `XDG_CONFIG_HOME` and the working directory into the
   sandbox. Pinning only one is what once created two worktrees in a live project.
2. The target repo is **disposable**: created under `mktemp -d`, deleted at the end. Never run this
   against melting, smoke-screen, depot, or the harness.
3. **No secret value is ever typed into a file.** The scenario uses shape-only synthetic strings,
   assembled at runtime.
4. Codex hook trust is **per-hash**: a changed or newly registered hook is *skipped* until approved.
   An untrusted hook is indistinguishable from a registered one, so every hook below must be
   observed to **fire**, not merely to appear in config.

---

## Claim → step map

Every claim CONTRACT §7 makes, and the step that exercises it. Nothing in §7 is unmapped.

`test/contract.test.sh` enforces two halves of this mechanically: every step below carries a
non-empty observable, and every step this table cites exists. It also checks that each of §7's
nine claim markers is represented here, so a new §7 guarantee cannot land unmapped. What it
cannot check is whether a mapping is *apt* — that a cited step genuinely observes the claim. That
judgement was made by reading §7 line by line, and the Depot rows above are the correction it
produced on the first pass.

| § | Claim | Step | Already automated by |
| --- | --- | --- | --- |
| §7 | Default T0–T2 journey is `wt` → build → ship | **C**, **H** | — |
| §7 | `MISSION.md` stays `scoping` when `write-plan` never runs | **C3** | `workspace.test.sh` |
| §7 | T3 adds spec-merge-first; parallel worktrees need the spec on `origin/main` | **G** | — |
| §7 | `code/` is a reference checkout; work happens in `worktrees/`, a peer | **B2** | — |
| §7 | Three creators, one location — `wt`, Depot, both providers | **C1**, **C4**, **D1**, **E1** | — |
| §7 | `wt` resolves the registry, or `git rev-parse --show-toplevel` inside a repo | **C1** | `workspace.test.sh` |
| §7 | `wt` fetches and branches from `origin/main`; no `--base` | **C1** | `workspace.test.sh` |
| §7 | `wt` creates `.workspace/` and runs `make setup` unless `--no-setup` | **C2** | `workspace.test.sh` |
| §7 | Claude's `WorktreeCreate` does the same two jobs | **D1** | — (needs Wave 1 T1.7) |
| §7 | Init is **eager** for `wt`, Depot, Claude | **C2**, **C5**, **D1** | partly |
| §7 | Init is **lazy** for Codex — no `WorktreeCreate` equivalent | **E1** | — |
| §7 | `ensure-workspace.sh` on SessionStart is the net for everything else | **F1** | `workspace.test.sh` |
| §7 | SessionStart orients read-only: state, next action, spec path, filenames, `git status` | **D2**, **E2** | `workspace.test.sh` |
| §7 | Orientation prints **filenames only, never contents** | **F3** | `workspace.test.sh` |
| §7 | Hook order is load-bearing — `ensure-workspace` before orientation, **both** providers | **F2** | `adopt.test.sh` |
| §7 | Cleanup is owned by the creator | **I1–I4** | — |
| §7 | Provider automatic cleanup stays enabled | **I4** | — |
| §7 | A retention sweep can take `.workspace/` and `LOG.md` with it; the PR body is the only bridge | **H3**, **I4** | — |
| §7 | Phone path: a phone-attached session fires the machine's SessionStart hook | **J** | — |

Adjacent claims the walk also has to prove, from the other sections:

| § | Claim | Step |
| --- | --- | --- |
| §2 | `.workspace/` is excluded via the **global** gitignore; no repo `.gitignore` mentions it | **B4** |
| §2 | `MISSION.md` is never overwritten by the initializer | **F1** |
| §2 | `write-plan` sets `state: building` + `spec:`; `/ship` sets `shipped` | **G3**, **H2** |
| §2 | A T3 build worktree's `spec:` has **no automated owner** — a human sets it | **G5** |
| §2 | `history/` creation is atomic; a colliding name retries `-2` | **F4** |
| §3 | A spec must be **merged**, not merely committed, before parallel worktrees are cut | **G4** |
| §5 | An adopted repo is discoverable by **both** providers; `.agents/skills` symlink resolves | **B3** |
| §5 | Codex hook trust is per-hash — each hook must be observed to fire | **E3** |
| §5 | `protect-secrets.sh` blocks a Codex `apply_patch`, and does not fail open | **E4** |
| §6 | Two mandatory local steps; **no reviewer runs automatically** | **H1** |
| §4 | The PR body carries `LOG.md`'s settled decisions | **H3** |

---

## The walk

### A — Preconditions (Wave 1 must have landed)

| # | Do | Observable |
| --- | --- | --- |
| A1 | `ls ~/.agents/skills \| wc -l` | the installed projection exists |
| A2 | `cat ~/.config/agents/projects.yaml` | the registry is at the new path and parses |
| A3 | `command -v wt` | resolves to `~/.local/bin/wt` |
| A4 | `grep .workspace ~/.config/git/ignore` | present (done: Wave 1 T1.1) |
| A5 | `./install.sh --dry-run` | exits 0 — no drift left unreconciled |

**Stop if any of A1–A5 fails.** The rest of the walk measures nothing if the machine is not set up.

### B — Adopt a disposable repo

| # | Do | Observable |
| --- | --- | --- |
| B1 | `T=$(mktemp -d)/app; mkdir -p $T; git -C $T init -b main; git -C $T commit --allow-empty -m init` | a real repo, outside every real project |
| B2 | Put it at `<container>/code/app` with a sibling `<container>/code/worktrees/` | `worktrees/` is a **peer** of the checkout, not inside it |
| B3 | `core/skills/adopt-harness/copy.sh $T python` | `AGENTS.md`, `CLAUDE.md` (a stub that `@AGENTS.md`), `.claude/`, `.codex/hooks.json`, `docs/`, `specs/`, `Makefile`; `.agents/skills` and `.claude/skills` are the same directory |
| B4 | `touch $T/.workspace/x && git -C $T status -uall --short` | `.workspace/` does not appear, and `git add -A && git ls-files` never lists it — **no repo `.gitignore` mentions it** |

> **Automated:** B3 and B4 are `adopt.test.sh` (32 assertions) and `workspace.test.sh`. Wave 2 re-runs
> them against a repo in the *real* container layout, which the suites cannot model.

### C — `wt` and Depot create worktrees (creators 1 and 2)

| # | Do | Observable |
| --- | --- | --- |
| C1 | `wt app --branch feat/thing` | branches from `origin/main`; the directory is the **last path segment** (`thing`); refuses with a non-zero exit and prints the existing path if the branch or directory already exists |
| C2 | `ls <container>/code/worktrees/thing/.workspace/` | `MISSION.md` exists and `make setup` already ran — init is **eager** |
| C3 | `head -3 .../MISSION.md` | `state: scoping`, `spec: null` — and it stays that way through a T0–T2 build, because `write-plan` never runs |
| C4 | Create a worktree through **Depot** | it lands in the same `worktrees/` root — Depot reads the same registry `worktree_root` |
| C5 | `ls .../.workspace/` in the Depot-created worktree | `MISSION.md` exists. **Depot did not create it** — Depot never creates, writes, validates, repairs, or interprets `.workspace/` (CONTRACT §1); the SessionStart net did, on first session |

> **Automated:** every refusal case and the ten-run idempotency are in `workspace.test.sh`, plus
> `wt` run from inside a worktree and a relative `worktree_root`. What Wave 2 adds is the **real
> registry**, the real container layout, and Depot itself — which no suite can stand in for.

### D — Claude creates a worktree (creator 3, provider 1) — eager

| # | Do | Observable |
| --- | --- | --- |
| D1 | Create a worktree from Claude | it lands in `<container>/code/worktrees/`, and `WorktreeCreate` has already run `ensure-workspace.sh` + `make setup` — `.workspace/` and installed deps exist **before** the first session |
| D2 | Open a session in it | orientation prints state, next action, spec path, the newest handoff **filename**, finding **filenames**, and a brief `git status` |

### E — Codex creates a worktree (creator 3, provider 2) — lazy, by design

| # | Do | Observable |
| --- | --- | --- |
| E1 | Create a worktree from Codex | it lands in the same `worktrees/` root, but `.workspace/` is **absent** until the first session — Codex has no `WorktreeCreate` equivalent |
| E2 | Open a Codex session in it | `.workspace/` appears (the SessionStart net), then the same orientation as D2. **The only observable difference from D is that deps install a few seconds later.** |
| E3 | Trust each hook hash, then trigger each event | every one of the seven repo-owned hooks is observed to **fire**. Config presence is not evidence — an untrusted hook looks identical. |
| E4 | Ask Codex to write `.env.local`, then a synthetic key | both are **blocked, exit 2**, through `apply_patch`. Then ask for an ordinary edit → allowed. |

> **Automated:** E4's payload handling is `hooks.test.sh` (40 assertions) against real `apply_patch`
> envelopes. What Wave 2 adds is the live provider and the **trust** step, which no test can fake.

### F — The invariants that hold regardless of creator

| # | Do | Observable |
| --- | --- | --- |
| F1 | `git worktree add` by hand, open a session; then edit `MISSION.md` and re-open | `.workspace/` is created by the net; the **existing `MISSION.md` is never overwritten** |
| F2 | Read `.claude/settings.json` and `.codex/hooks.json` | `ensure-workspace.sh` precedes `spec-session-orient.sh` in **both** SessionStart lists |
| F3 | Put a distinctive marker string inside a handoff **body**, re-open the session | the marker never reaches context — orientation prints filenames only |
| F4 | Run two `workspace-record finding same-slug` in the same second | two distinct files; the second is `-2`. No overwrite, no lost record |

### G — T3: the spec-merge-first sequence

| # | Do | Observable |
| --- | --- | --- |
| G1 | `wt app --branch plan/epic` | a planning worktree, off `origin/main` |
| G2 | `brainstorm` → `grill` | `DECISION` / `QUESTION` entries accumulate in `.workspace/LOG.md`; **no ADR, glossary entry, or architecture change is written without asking** |
| G3 | `write-plan` | `specs/epic/README.md` + `01-*.md`; this worktree's `MISSION.md` flips to `state: building` with `spec:` set |
| G4 | Spec-only PR → **merge to main** | a worktree cut *before* the merge cannot see the spec; one cut after can. This is why merge, not commit, is the gate |
| G5 | `wt app --branch task-1` and `--branch task-2`; set each `MISSION.md`'s `spec:` | both build worktrees point at the same spec path. **Nothing did this for you** — it is the one `MISSION.md` write with no automated owner |
| G6 | Build both in parallel | separate `.workspace/` directories; no coordination mechanism, and none needed |

### H — Ship

| # | Do | Observable |
| --- | --- | --- |
| H1 | Finish a change and stop | the Stop gate re-runs `make check` and blocks until green. **No reviewer ran.** Neither `reviewer` nor `reviewer-security` was invoked by anything but you |
| H2 | `/ship` | `MISSION.md` gets the final position and `state: shipped` |
| H3 | Read the PR body | it contains `LOG.md`'s settled decisions, including what was **rejected and why**. Nothing checked that this happened — confirm it by reading |

### I — Removal is owned by the creator

| # | Do | Observable |
| --- | --- | --- |
| I1 | Remove the `wt`-created worktree via Depot's guarded trash | gone; the guard asked first |
| I2 | Let Claude clean up its own worktree on exit/archive | gone, by its own mechanism — not Depot's |
| I3 | Let Codex archive its worktree | gone; Codex saves a snapshot |
| I4 | Leave one worktree with a populated `LOG.md` and let a retention sweep take it | `.workspace/` and `LOG.md` are **gone**, and the PR body is the only surviving record. This is the accepted loss — observe it once, deliberately, rather than discovering it |

### J — Phone path

| # | Do | Observable |
| --- | --- | --- |
| J1 | Attach from the phone to a Depot-launched tmux session | the machine's SessionStart hook fired, so `.workspace/` exists and orientation appeared. **No Depot change was required** |

### K — Teardown

| # | Do | Observable |
| --- | --- | --- |
| K1 | Remove the disposable container and every branch it created | `git worktree list` and `git branch -a` show nothing left over |
| K2 | `./install.sh --dry-run` | still exits 0 — the walk changed nothing on the machine |

---

## Pass condition

The scenario passes when **every observable above was seen**, and specifically when all four of
these — the ones no unit test can reach — were seen on a live machine:

1. A **Claude-created** worktree had `.workspace/` and installed deps *before* its first session.
2. A **Codex-created** worktree got them at first SessionStart instead, and nothing else differed.
3. Every Codex hook was **trusted and observed to fire**, and `protect-secrets.sh` blocked a real
   `apply_patch` rather than failing open.
4. A PR body carried the settled decisions after its worktree was gone.

Anything not seen is reported as not seen. A scenario is not evidence of what it did not observe.
