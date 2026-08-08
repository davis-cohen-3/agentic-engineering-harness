---
name: adopt-harness
description: >-
  Use to onboard this portable harness into the CURRENT repository — copy the
  traveling tree, then scout this codebase and draft its profile/gate/docs fills.
  Trigger on "adopt the harness into this repo", "onboard this repo", "set up the
  harness here". Runs from a session IN the target repo, reading this skill by path
  from a local clone of the harness.
---

# Adopt the harness into a repo

STARTER_CHARACTER = 📦 — open each reply with it while this skill is active.

Onboarding = fill the slots, not rebuild the harness. The mechanical copy is
deterministic (`copy.sh`); the judgment is grounding the fills in how *this*
codebase actually works. Do the copy, then use subagents to learn the repo, then
draft the fills for the user to confirm.

## 1. Copy the traveling tree
This session runs IN the target repo, pointed at a local clone of the harness (e.g.
`~/agentic-coding-harness`). Ask the user for that harness path and the gate flavor
(`python`/`ts`/`none`), then run the manifest copy with the target as `.` (here):

```
<harness-path>/.claude/skills/adopt-harness/copy.sh . [python|ts|none]
```

`copy.sh` is self-locating (it finds the harness from its own path) and owns the manifest
(the definition of what travels). It never clobbers an existing `CLAUDE.md` or `make/gate.mk`
and prints the slots still to fill. **Adopt once per repo** — the rest of the tree is a
recursive copy, so a re-run can overwrite already-filled files.

## 2. Scout this repo (subagents — don't read it all yourself)
You're already in the target, so `scout` runs against it natively (no `git -C` needed).
Spawn `scout` to map what the fills need:
- stack: languages, frameworks, package manager, datastores; sub-projects in a monorepo
- structure: where the important things live (the structure map)
- the real **gate** commands: how the repo builds, tests, lints, typechecks (+ any custom
  architecture linters — the base can't discover these; the overlay must enumerate them)
- conventions already in force; risk-prone areas (the tuned hotspots)
- domain language for the glossary
Spawn `researcher` only for a genuinely unfamiliar framework whose idioms aren't obvious
from the code. Keep exploration in the subagents — return the map, not the file dumps.

## 3. Draft the fills, then confirm
From scout's map, draft — and show the user before writing:
- **`CLAUDE.md`** — replace every `<FILL>` (what / stack / structure / conventions / hotspots).
- **`make/gate.mk`** — set `GATE_STEPS` (and `SETUP_STEPS`) to the repo's REAL checks, ordered
  (e.g. build before typecheck if types are generated). Add custom linters here.
- **`agent_docs/architecture.md` + `glossary.md`** — the system shape + domain terms.
Onboarding is judgment work: propose, let the user correct, then write. Don't invent facts the
scout didn't find — flag gaps instead.

## 4. Verify (the portability + done check)
- `make setup && make check` → green (the gate this repo just declared) — run natively, you're here.
- Confirm the copied tree is clean: no `docs/`, no `recommended/` catalogs, no
  `adopt-harness/`; `CLAUDE.md` is the filled profile; `.claude/FLOOR.md` byte-identical to base.
- Hand back: what was filled, what the gate ran, any slot left for the user.
