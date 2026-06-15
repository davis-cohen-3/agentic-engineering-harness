# Authoring `.claude/rules/`

How the `.claude/rules/` directory works and where a rule belongs. This guide lives in `docs/`
(harness-author space, load-on-demand) **on purpose** — see "Why this isn't a README" below.

> Native Claude Code feature — requires **CC ≥ 2.1.101**. Authoritative reference:
> https://code.claude.com/docs/en/memory#organize-rules-with-claude/rules/

## What rules are
Modular instruction files that live outside `CLAUDE.md`. They are **standards the agent
follows for this codebase** — split into their own files for organization, and optionally
scoped to the files they govern. Two load modes, **both first-class**:

| Frontmatter | When it loads | Use it for |
|---|---|---|
| **no `paths:`** | every session, **same priority as `CLAUDE.md`** | always-on standards you want as their own file instead of more lines in the floor |
| **with `paths:`** | only when the agent reads a file matching a glob | advice scoped to a file-type/area — off-budget until relevant |

```markdown
---
paths:
  - "src/api/**/*.{ts,tsx}"
  - "**/migrations/**"
---
# The standard. Explain the *why*, not the *what*.
```
Globs support `**` and brace expansion (`{ts,tsx}`). A `paths:` rule **always** applies when a
matching file is in scope — there is no `alwaysApply: false` opt-out. Path-scoped rules trigger
when Claude *reads* a matching file, not on every tool use. Worked examples ship in the rules
directory: `migrations.md` and `specs.md`.

## The token-budget caveat (not a prohibition)
A **no-`paths:`** rule costs the *same* always-on tokens as the equivalent lines in `CLAUDE.md`
— the loader treats it with identical priority. So splitting standards into no-`paths:` files
buys **organization and maintainability** (modular files, each `CLAUDE.md` under ~200 lines),
**not** token budget. Split for modularity or to path-scope — not for mere tidiness, which only
adds indirection at the same cost. Real token savings come only from `paths:` scoping.

## Why this isn't a README
Every `*.md` under `.claude/rules/` is discovered recursively, and any file **without**
`paths:` loads at launch. A `README.md` dropped there has no `paths:`, so it would load into
**every** session as an always-on tax — a directory-explainer masquerading as a rule. That's
why this guide lives in `docs/` rather than in `rules/` itself.

## Where a rule belongs (one home per concern)
| The rule is… | Home | Why |
|---|---|---|
| universal · short · always relevant | **`CLAUDE.md`** | the floor; every task pays for it, so it must earn it broadly |
| a standard you want as its own always-on file | **`.claude/rules/`** (no `paths:`) | modular; same cost as the floor, cleaner to maintain |
| advisory · scoped to a file-type/area | **`.claude/rules/` + `paths:`** | declarative, automatic, off-budget until a matching file is touched |
| procedural ("how to do task Y") | **a skill** (`.claude/skills/`) | model-invoked by description; carries process steps |
| must hold regardless of what the model decides | **a hook** (`.claude/hooks/`) | deterministic; survives `--dangerously-skip-permissions` |
| deep reference (architecture, glossary, decisions) | **`agent_docs/`** | read on demand when orienting; too big for always-on |

## Don't
- **Don't put enforcement here.** A rule that must *hold* (not just be *seen*) is a hook —
  `rules/` is advice, and advice an autonomous run can ignore.
- **Don't restate a linter.** Style/format rules are the gate's job (`make check`), not prose.

## Base vs overlay
The base ships the worked examples (`migrations.md`, `specs.md`); real rule content references a
repo's own layout (`src/api/**`, `db/migrate/**`), so it's **overlay** content dropped in at
onboarding — same as filling any other slot. See `OVERLAY-CONTRACT.md` for the slot model.
