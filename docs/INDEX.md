# docs/ — the harness author's space

Durable truth about **why this harness is shaped the way it is**. This directory does **not**
travel into an adopting repo — `adopt/docs/` is the scaffolding that does.

`docs/` holds durable repository truth only. **Planning and research artifacts live with the work
they inform**, under `specs/<epic>/`, and age out with it — see
`specs/harness-standardization/` for this epic's contract, decisions, design review and research.

| File | Holds |
| --- | --- |
| `OVERLAY-CONTRACT.md` | the slot contract an adopting repo fills |
| `PLAN-MODE.md` | why the plan/build split is shaped this way — narrative, not operational steps |
| `CLAUDE-CODE-RULES.md` | how to author a `paths:`-scoped rule file |
| `AGENT-ANTIPATTERNS.md` | observed agent failure modes and the mitigation each earned |
| `SOURCES.md` | where vendored and adapted material came from |
| `recommended/` | the curation catalogs — skills, agents, hooks, MCPs, and the anti-bloat cap |

## Where other things live
- **The profile** — `AGENTS.md` at the repo root; `CLAUDE.md` imports it.
- **The two payloads** — `core/` (machine, via `install.sh`) and `adopt/` (target repo, via
  `copy.sh`). `AGENTS.md`'s structure map is the authority.
- **Specs** — `specs/`. The traveling scaffold for adopters is `adopt/specs/`.
- **Scaffolding for an adopted repo's own docs** — `adopt/docs/` (`INDEX.md`, `architecture.md`,
  `glossary.md`, `adrs/`).
