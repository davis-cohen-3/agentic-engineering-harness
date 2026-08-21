---
name: adopt-harness
description: >-
  Use to onboard this portable harness into the CURRENT repository — copy the
  adopt/ payload, then scout this codebase and draft its profile/gate/docs fills.
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

## 1. Copy the adopt/ payload
This session runs IN the target repo, pointed at a local clone of the harness (e.g.
`~/agentic-coding-harness`). Ask the user for that harness path and the gate flavor
(`python`/`ts`/`none`), then run the manifest copy with the target as `.` (here):

```
<harness-path>/core/skills/adopt-harness/copy.sh . [python|ts|none]
```

`copy.sh` is self-locating (it finds the harness from its own path) and owns the manifest
(the definition of what travels). It homes everything at the provider-neutral `.agents/` root —
hooks at `.agents/hooks/`, briefs at `.agents/briefs/`, skills at `.agents/skills/` — and wires
the thin adapters both providers resolve through: `.claude/skills` symlinks to the skills home
(Codex scans `.agents/skills` natively), `.claude/agents/*.md` symlink to the briefs,
`.codex/agents/*.toml` point at them by path, and both providers' hook bindings are installed.
A repo adopted before the neutral root is migrated in place.

**Re-running is safe, and IS the upgrade path.** Anything a repo fills in — `CLAUDE.md`,
`AGENTS.md`, `make/gate.mk`, `specs/README.md`, the docs scaffolds — is written only when absent.
Hook **bindings** MERGE (keyed by event + script) — Claude bindings into
`.claude/settings.local.json` (the team's `settings.json` is read for dedup but never written),
Codex bindings into `.codex/hooks.json`. Everything else is MANAGED and updates by a three-way
comparison against `.agents/MANIFEST`: untouched entries refresh, locally-edited ones are held
and counted, and an entry changed on BOTH sides is a loud conflict — the run exits 1 and names
each path. Resolve conflicts one decision at a time with
`copy.sh --resolve <path>=<upstream|local|omit> .` and re-run; entries in the harness's
`adopt/CRITICAL` (the security hooks) block the ✅ until resolved. Never resolve a CRITICAL
conflict for the user — show them both sides and ask.

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
- **`AGENTS.md`** — replace every `<FILL>` (what / stack / structure / conventions / hotspots).
  This is THE profile: Codex reads it natively and `CLAUDE.md` imports it, so write each fact
  once, here. Never restate it in `CLAUDE.md`.
- **`make/gate.mk`** — set `GATE_STEPS` (and `SETUP_STEPS`) to the repo's REAL checks, ordered
  (e.g. build before typecheck if types are generated). Add custom linters here.
- **`docs/architecture.md` + `docs/glossary.md`** — the system shape + domain terms.
Onboarding is judgment work: propose, let the user correct, then write. Don't invent facts the
scout didn't find — flag gaps instead.

## 4. Verify (the portability + done check)
- `make setup && make check` → green (the gate this repo just declared) — run natively, you're here.
- Confirm the copied tree is clean: no `recommended/` catalogs, no `adopt-harness/`, no retired
  spec companions (`*.context.md`, `spec.thoughts.md`, `spec.sessions/`); `AGENTS.md` is the
  filled profile and `CLAUDE.md` only imports it.
- Confirm BOTH providers can see it: `.claude/skills` resolves to the `.agents/skills` home
  (`make check`'s harness canary asserts this), and the
  doctor is green — `copy.sh` runs it automatically (no ✅ without it), and it can be re-run
  any time: `<harness-path>/core/skills/adopt-harness/copy.sh --doctor .` — every hook
  present, bound per provider, and fired clean against a benign payload. If it warns about a
  missing Codex trust entry, tell the user their next Codex session must accept the hooks.
- Hand back: what was filled, what the gate ran, any slot left for the user.
