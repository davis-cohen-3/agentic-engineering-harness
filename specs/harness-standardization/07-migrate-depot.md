> ## ⚠ SUPERSEDED — DO NOT EXECUTE
>
> Uses an older target model. **The factual audit evidence in it is still good** — harvest it. Replaced by task T2.1.
>
> **Authority:** `DECISIONS-PENDING.md` → `CONTRACT.md` →
> `HARNESS-DEPOT-OPERATIONAL-DESIGN-REVIEW.md` → `plan/tasks.md`.
> Retained as provenance and research. Harvest evidence from it; do not run its instructions.
>
> *Bannered 2026-08-08.*

---
status: superseded
tier: T3
hotspots: [migrations]
---

# 07 · Migrate depot (three mirrors, one stale fork)

> Part of the [harness standardization](./README.md) epic — read its **Shared context** and
> **Epic-level decisions** first. Apply the recipe established in [task 06](./06-migrate-melting.md).

## Goal
Collapse depot's three drifting config mirrors into one source, and fix the stale `AGENTS.md` that
has been feeding Codex an obsolete description of the repo. depot is the worst-drifted repo on the
machine; it goes second so the recipe is already proven.

Ships as a PR against the depot repository.

## Approach (resolved at the epic level — execute, don't re-decide)

### The damage, as found in the audit
depot carries **three** config trees — `.claude/`, `.codex/`, `.agents/` — plus **two** instruction
files that were forked rather than imported. All four problems are live:

1. **`AGENTS.md` is an architecture generation out of date.** `CLAUDE.md` describes depot as
   "a local-first web cockpit… launchd-supervised FastAPI daemon drives tmux and SQLite; a React
   PWA renders the cockpit… The old Textual TUI is retired and removed." `AGENTS.md` describes it
   as "a single-pane Textual TUI" that is "in transition," with `src/depot/app.py` and
   `src/depot/screens/` marked FROZEN. **Every Codex session in this repo has been reading the
   second one.** The structure map, the stack line, and the transition warning are all wrong.
2. **`AGENTS.md:7` imports `@.Codex/FLOOR.md`** — capital `C`. It resolves to nothing. Even the
   stale floor never loaded.
3. **`.claude/hooks/spec-session-orient.sh` differs from `.codex/hooks/spec-session-orient.sh`.**
   Unexplained divergence in a hook that decides what every session sees at startup.
4. **`.agents/skills/` is missing `VENDORED.md`** relative to `.claude/skills/` — a third copy,
   drifting on its own schedule.

### Target
- **`AGENTS.md` is the single source**, rewritten from `CLAUDE.md`'s current (correct) content.
  `CLAUDE.md` becomes the adapter: `@AGENTS.md` plus any genuinely Claude-only routing, mirroring
  melting-v2's shape. **Reconcile before collapsing** — read both files fully and confirm nothing
  true survives only in the stale one. The transition note in `AGENTS.md` is stale, but verify
  against the actual tree (does `src/depot/screens/` still exist?) rather than trusting either file.
- **One config tree.** `.claude/` is canonical. `.codex/` keeps only what Codex needs and cannot
  read from `.claude/` — its own `hooks.json` and `agents/*.toml`. Everything duplicated verbatim
  becomes a **symlink** into `.claude/`, so it cannot drift again. `.agents/skills/` → symlink to
  `.claude/skills/`. Before collapsing #3, determine which `spec-session-orient.sh` is correct;
  the difference is a fact about the repo, not noise to discard.
- **Commands lifted from `gate.mk` into `AGENTS.md`.** depot's is the most interesting on the
  machine because it spans two toolchains:
  ```
  GATE_STEPS  = format lint test web-check
  web-check:  cd web && npm run format && npm run lint && npm run typecheck && npx vitest run && npm run build
  ```
  The `web-check` arm is five commands hidden behind one name — precisely the indirection this
  epic removes. Split it: root Python commands (`uv run ruff format --check src tests`,
  `uv run ruff check src tests`, `uv run pytest -q`) go in the root `AGENTS.md`; the five web
  commands go in **`web/AGENTS.md`**, which loads only when something under `web/` is touched.
  This is the clearest per-area win in the epic.
  Also carry over the standing note that **no typechecker is configured** — the code is fully
  type-hinted but unenforced, and adding mypy/pyright is a deliberate decision, not a mechanical
  one. That comment currently lives in `gate.mk` and would be lost with it.
- **Bootstrap** (`uv sync`, `cd web && npm install`) becomes a prose line, along with the existing
  manual prerequisite: `~/.config/depot/projects.yaml` must exist or the app raises
  `FileNotFoundError`.
- **Keep the non-gate Makefile targets.** depot's `gate.mk` also holds `daemon-dev`, `deploy`,
  `web-build`, `install`, `serve-setup` — real operator commands, unrelated to checks. They do not
  belong in `AGENTS.md` and must not be deleted with the gate. Move them to a `Makefile` that
  contains only them, or to `scripts/`; either is fine, but decide once and note it in the PR.
  **`deploy` and `serve-setup` are the reason this task carries a hotspot** — see below.
- **`FLOOR.md`** deleted from `.claude/` (and the phantom `.Codex/` reference from `AGENTS.md`).
- **`lint-edited-file.sh`** filled with both toolchains: `*.py` → `uv run ruff check --fix`,
  `web/**/*.ts{,x}` → `npx eslint --fix`.

## Task decomposition
1. Reconcile `CLAUDE.md` vs `AGENTS.md` against the actual tree; write the true `AGENTS.md` — deps: none
2. `CLAUDE.md` → adapter (`@AGENTS.md` + Claude-only routing); delete the `.Codex/FLOOR.md` import — deps: #1
3. Split the gate: Python commands → root `AGENTS.md`; the five web commands → `web/AGENTS.md`;
   carry the no-typechecker note and the bootstrap prerequisites — deps: #1
4. Rehome `daemon-dev`/`deploy`/`web-build`/`install`/`serve-setup`; delete the gate targets — deps: #3
5. Determine the correct `spec-session-orient.sh`; collapse `.codex/` and `.agents/` to symlinks
   into `.claude/`, keeping only Codex-native files real — deps: none
6. Delete `.claude/FLOOR.md`; refresh `.claude/` from the base — deps: #5
7. Fill `lint-edited-file.sh` for both toolchains — deps: #6

## Acceptance criteria
- [ ] #1: every fact in the new `AGENTS.md` is verified against the tree, not copied from either
      old file — specifically the stack line, the structure map, and whether the Textual TUI still exists
- [ ] #2: `rg -n "FLOOR|\.Codex" AGENTS.md CLAUDE.md .claude/ .codex/` returns nothing
- [ ] #2: `CLAUDE.md` opens with `@AGENTS.md`; `/context` shows `AGENTS.md`'s content loaded
- [ ] #3: `web/AGENTS.md` exists and names all five web commands; the root file names none of them
- [ ] #3: reading a file under `web/` in a live session loads `web/AGENTS.md` on demand; reading a
      file under `src/depot/` does not
- [ ] #3: the no-typechecker note survives, in `AGENTS.md`
- [ ] #4: `depot doctor` (or the equivalent smoke command) still works, and `make daemon-dev` /
      its replacement still starts the daemon — run, not assumed
- [ ] #5: `readlink` confirms `.agents/skills` and every duplicated `.codex/` path point into
      `.claude/`; `diff -rq` finds no remaining duplicated regular file
- [ ] #5: the `spec-session-orient.sh` divergence is resolved with a stated reason in the PR
      description — not silently overwritten
- [ ] #7: editing a `.py` file and a `web/**/*.ts` file each surface their own linter's errors
- [ ] every command named in either `AGENTS.md` runs green from a clean `uv sync` + `npm install`

## Out of scope
- depot's application code and its `specs/agent-dashboard/` epic.
- `opt/depot` — a worktree of this repo; it regenerates. Task 08 confirms it, nothing more.
- The `lib/{install,sync}-harness.sh` local-only harness-travel mechanism, whose manifest lives in
  `.git/info/exclude`. It is explicitly *not* the committed harness — depot's own structure map
  warns not to confuse the two. Leave it alone; note in the PR if it now conflicts.

## Risk hotspots touched
- **prod deploy** → engage `reviewer-security`. `make deploy` runs `git pull --ff-only`, `uv sync`
  and `launchctl kickstart` against the live daemon; `serve-setup` exposes the daemon over the
  tailnet and its script asserts Tailscale **funnel is off**. Rehoming these targets (#4) must not
  change their behavior, drop the funnel assertion, or alter the `--check` read-only preflight.
  Verify the rehomed commands are byte-equivalent in effect before deleting the originals.
- **migrations** is declared in this spec's frontmatter because depot's gate omits any migration
  step and the repo has a `db/`-adjacent surface; if the migration story surfaces during the
  rewrite, it is a finding for the PR, not something to fix here.

## Context pointers
- `AGENTS.md` and `CLAUDE.md` — the fork to reconcile; `diff` them first, then check both against the tree
- `make/gate.mk` — holds the `web-check` arm, the no-typechecker note, and the five operator targets
- `.claude/hooks/spec-session-orient.sh` vs `.codex/hooks/spec-session-orient.sh` — the divergence
- `scripts/serve-setup.sh` — the funnel assertion that must survive #4
- `.claude/worktrees/` — six existing worktrees; they regenerate, do not migrate them

## Verification
- checks: both toolchains' commands, from a clean bootstrap, reported with output
- manual: start a Codex session and confirm it now reads the *correct* repo description — this is
  the specific harm being fixed and it must be observed, not inferred. Then start a Claude session,
  read a `web/` file, and confirm `web/AGENTS.md` loads. Run the rehomed `daemon-dev` and confirm
  the daemon starts (`verify-before-done`).
- Do **not** run `deploy` as verification.
