> ## ⚠ SUPERSEDED — DO NOT EXECUTE
>
> Makes `~/agents` canonical, points `~/.agents` back at Claude, deletes the injection hook, and excludes Codex hooks. All four are reversed. Replaced by Wave 1.
>
> **Authority:** `DECISIONS-PENDING.md` → `CONTRACT.md` →
> `docs/HARNESS-DEPOT-OPERATIONAL-DESIGN-REVIEW.md` → `plan/tasks.md`.
> Retained as provenance and research. Harvest evidence from it; do not run its instructions.
>
> *Bannered 2026-08-08.*

---
status: superseded
tier: T3
hotspots: []
---

# 05 · Machine layer — `~/agents`, `~/.claude`, `~/.codex`

> Part of the [harness standardization](./README.md) epic — read its **Shared context** and
> **Epic-level decisions** first.

## Goal
Give the machine one general instruction file that both Claude Code and Codex load natively, and
retire the bespoke hook that currently emulates it. After this run, `~/agents/AGENTS.md` is the
single source for cross-repo preferences and `inject-global-rules.sh` is gone.

**This run edits files outside any git repository.** Snapshot first (see Task decomposition #0) —
there is no PR to revert.

## Approach (resolved at the epic level — execute, don't re-decide)

### Current state (from the audit)
- `~/.claude` is a **symlink** → `~/agents/claude`. `~/.codex` and `~/.agents` are **real
  directories**. `~/agents/codex/` and `~/agents/hermes/` exist and are **empty** — a consolidation
  under `~/agents/` that was started and abandoned.
- There is **no `~/.claude/CLAUDE.md`**. Instead `~/.claude/settings.json` wires a SessionStart
  hook, `inject-global-rules.sh`, which concatenates `~/.claude/rules/*.md` and **suppresses them
  entirely** inside any directory owning a `.claude/` or `CLAUDE.md`.
- `~/.codex/AGENTS.md` exists and is **empty**.
- `~/.agents/skills/` is a **third copy** of the skills tree (alongside `~/.claude/skills/` and
  each adopted repo's).

### Target
- **`~/agents/AGENTS.md`** — the one canonical machine file. Symlink both entry points at it:
  `~/.claude/CLAUDE.md` → `../AGENTS.md` (resolves through the existing `~/.claude` symlink
  to `~/agents/claude/CLAUDE.md`, so create it as a real symlink at `~/agents/claude/CLAUDE.md`)
  and `~/.codex/AGENTS.md` → `~/agents/AGENTS.md`. Symlinks are correct *here* — unlike the repo
  level, there is no per-tool content to append, and both files must be byte-identical by
  construction. Verify each with `/context` (Claude) and by inspection (Codex).
- **Content** = the four current rule files, merged and generalized. They are already close: the
  epic README's table shows `00-preferences.md` restates FLOOR's workflow section nearly verbatim.
  Merge `00-preferences.md`, `secrets.md`, `scratch-work.md`; drop `README.md` (it documents the
  hook being deleted). Then **generalize** — every line must be true inside a project too, because
  the file no longer hides there. Concretely: `scratch-work.md`'s "don't litter `$HOME`" and
  "`git init` a throwaway repo" are loose-work-only and either get an explicit "for scratch work
  outside a repo:" qualifier or are cut. `00-preferences.md`'s "Suppressed inside any project that
  owns its own `.claude/`" preamble is deleted — it describes behavior that no longer exists.
- **Delete** `~/.claude/hooks/inject-global-rules.sh` and its SessionStart entry in
  `~/.claude/settings.json`. Leave every other setting in that file alone.
- **`~/.agents/skills/`** → replace the directory with a symlink to `~/agents/claude/skills`.
  Diff the two first and reconcile any real difference before collapsing them; the audit already
  found depot's copies had drifted, so assume these have too.
- **Leave `~/agents/codex/` and `~/agents/hermes/` empty** and untouched. They are inert. Removing
  them is tidying with no benefit and a small chance of breaking something unexamined.

### Size discipline
Codex caps merged `AGENTS.md` at 32 KiB (`project_doc_max_bytes`) and *silently stops adding files*
at the limit — a machine file that grows unchecked starves the project file that matters more.
Claude's guidance is under 200 lines. The merged file should land well under both; if it doesn't,
that is the signal that something in it is project-specific and belongs in a repo's `AGENTS.md`.

## Task decomposition
0. `cp -R` snapshot of `~/agents/claude/{rules,hooks,settings.json}`, `~/.codex/AGENTS.md` and
   `~/.agents/` to a dated directory under `~/scratch/` — deps: none
1. Merge + generalize the three rule files into `~/agents/AGENTS.md` — deps: #0
2. Symlink `~/agents/claude/CLAUDE.md` and `~/.codex/AGENTS.md` at it — deps: #1
3. Delete `inject-global-rules.sh` + its SessionStart entry; delete `~/agents/claude/rules/` — deps: #2
4. Diff `~/.agents/skills` vs `~/agents/claude/skills`, reconcile, replace with a symlink — deps: none

## Acceptance criteria
- [ ] #1: every line of the merged file is true inside a project as well as outside — checked
      line by line, with the loose-work-only lines either qualified or removed
- [ ] #1: no secret *values* in the file; `~/.claude/secrets.env` is referenced by path and its
      variables by `${VAR}` name only
- [ ] #2: `/context` in a fresh session **inside** `dev/agentic-engineering` lists the user
      `CLAUDE.md` under Memory files **and** the project's — both, concatenated, user first.
      (Under the old hook the global rules were absent here; that change is the point.)
- [ ] #2: `/context` in a fresh session in `~/scratch` lists the user `CLAUDE.md`
- [ ] #2: `readlink ~/.codex/AGENTS.md` resolves to `~/agents/AGENTS.md` and the file is non-empty
      (it was empty before — this is the first time Codex has had a machine layer)
- [ ] #3: no SessionStart hook remains in `~/.claude/settings.json`; the other keys (`model`,
      `effortLevel`, `enabledPlugins`, `theme`, …) are byte-identical to the snapshot
- [ ] #3: a fresh session emits no rule-injection system-reminder
- [ ] #4: `~/.agents/skills` is a symlink; `ls ~/.agents/skills/` lists the same skills as
      `~/agents/claude/skills/`
- [ ] merged file is under 200 lines and under 32 KiB

## Out of scope
- Any repository. This task is entirely outside version control.
- `~/agents/claude/{agents,commands,skills}` contents — unchanged; `scripts/install-global.sh`
  (from task 01) still syncs them.
- `~/.codex/hooks/`, `~/.codex/config.toml`, `~/.codex/agents/` — the Codex-side hook/agent story
  is real work and is not in this epic. This task gives Codex a machine instruction file, nothing more.
- `life/CLAUDE.md` and `personal/CLAUDE.md` — loose non-code directories, deliberately left as-is.

## Risk hotspots touched
- **Not** a convergent hotspot, but this is the only task in the epic with **no PR and no revert**.
  Step #0's snapshot is not optional. Additionally: a wrong `~/.claude/settings.json` edit degrades
  every session on the machine, so change only the `hooks` key and diff the file against the
  snapshot before finishing.
- Secrets: the rule files being merged are *about* secret handling; do not let a `.env` path or a
  token get inlined during the merge.

## Context pointers
- `~/.claude/rules/{00-preferences,secrets,scratch-work,README}.md` — the sources to merge
- `~/.claude/hooks/inject-global-rules.sh` — read its header before deleting; it documents the
  suppression rationale that epic decision 2 supersedes
- `~/.claude/settings.json` — only the `hooks` key changes
- [Memory · precedence](https://code.claude.com/docs/en/memory) — user file loads before project,
  both concatenated
- [Codex · AGENTS.md](https://developers.openai.com/codex/guides/agents-md) — `~/.codex/AGENTS.md`
  is the global layer; 32 KiB cap

## Verification
- checks: none apply (no repo)
- manual: every `/context` assertion above run for real in a fresh session — one inside a project,
  one outside. The behavioral change here is *invisible* except through `/context`, so reading the
  files proves nothing (`verify-before-done`). Keep the snapshot until tasks 06–08 are done.
