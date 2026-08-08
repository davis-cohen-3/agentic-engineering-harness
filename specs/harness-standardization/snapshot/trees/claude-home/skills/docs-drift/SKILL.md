---
name: docs-drift
description: Check whether this repo's documentation still matches its code, and report concrete drift (a documented path/command/module/contract the code no longer honors). Report-only — never edits code, never blocks. Use on demand ("check docs drift", "are the docs still accurate") or as a scheduled hygiene run. Skip for docs describing unbuilt/aspirational work — that's a plan, not drift.
argument-hint: "optional: --since <ref> to widen the window, or a subpath to focus on"
---

# docs-drift — is the documentation still true to the code?

STARTER_CHARACTER = 🪞 — open each reply with it while this skill is active.

Check whether THIS repo's docs still describe its code truthfully, and surface concrete drift.
**Report-only:** never block a push or gate, never edit code, never auto-merge doc fixes without a
yes. **Zero findings is the common, correct outcome** — prefer silence to a weak flag.

## Scope to the current repo (no hardcoded paths)
- Repo root = `git rev-parse --show-toplevel`; everything below is relative to it.
- **Docs** = `CLAUDE.md`, `agent_docs/**`, `README*`, and contract docs under `specs/**`.
- **Code** = the real tree — source dirs, `Makefile` / `make/**` / package scripts, manifests.

## Bound the work — what changed
- Default window: what changed on the default branch in the last ~26h
  (`git log --since="26 hours ago"`, `git diff --name-only`). A `--since <ref>` arg widens it; a
  subpath arg focuses it.
- **If nothing changed in scope, say so and stop** — no issue, no noise. (Interactive only: run a
  full pass anyway if the user explicitly asks.)

## The checks — only concrete, verifiable drift
For each changed code area, confirm the docs that describe it are still true:
1. **Layout** — the directory/layer map in `CLAUDE.md` / `agent_docs/architecture.md` vs the real tree.
2. **Commands** — documented `Makefile` targets, `make/*.mk`, package scripts, the gate vs what exists.
3. **Responsibilities** — module/ownership claims in `agent_docs/**` vs the code they describe.
4. **Contracts** — a `specs/**` doc whose task has *shipped* but whose stated contract (paths, table
   names, enum values, endpoints) no longer matches the merged code.
5. **Dead references** — a documented path / file / symbol / command that no longer exists.

Keep ONLY findings you can point to with `file:line` on **both** sides. Discard cosmetic wording,
style, and anything uncertain. When in doubt, drop it.

## The one trap — aspirational ≠ drift
A doc describing work that is **not built yet** (a spec, a roadmap, a "will" statement, an
empty-but-documented layer home) is a **plan, not drift**. Only flag docs that assert the
**current** state and are now false. If unsure whether a doc is descriptive or aspirational, treat
it as aspirational and stay silent.

## Output — match how you're running
- **Interactive** (a person is here): report findings inline as
  `doc:line — says X — code shows Y — suggested fix`, grouped by doc file. Offer to apply the
  **doc-only** fixes; apply only on an explicit yes. Never touch code.
- **Unattended** (scheduled/automated): if there are real findings, open **one** GitHub issue
  (`gh issue create --title "Docs drift: <area>"`), first checking for an existing open
  "Docs drift" issue to **update** instead of duplicating. If every finding is a mechanical
  doc-only fix, a **draft** PR (`docs/drift-YYYY-MM-DD`, doc files only, never merged) is fine.
  Nothing drifted → exit silently.

## Never
- Never run the build / tests / migrations to "check" — this is read-and-analyze only.
- Never block a push, fail a gate, or auto-merge a doc fix.
- Never open a second issue when one is already open — update it.
