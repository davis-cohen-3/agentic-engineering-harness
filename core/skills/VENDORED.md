# Vendored skills — attribution & local modifications

Some skills here are **copied from upstream projects** — their content, not ours. Attribution
and license live in this one file so the skill files themselves stay clean (verbatim where
verbatim). Pipeline wiring — when each skill runs, what feeds what — stays in `CLAUDE.md` and the
skills' own triggers, deliberately NOT stapled onto a vendored skill.

| skill | source | commit | license | local changes |
|-------|--------|--------|---------|---------------|
| `grill-me` | mattpocock/skills · `skills/productivity/grill-me` | be55a79 | MIT © Matt Pocock | + local sections "Ground the grilling in this codebase" (→ `agent_docs/`) and "Record the thread" (→ `thoughts.md`); + a `STARTER_CHARACTER` marker line (🔥) |
| `tdd` (+ `references/zombies.md`) | lexler/skill-factory · `output_skills/testing/tdd` | 83aee6a | Apache-2.0 © Lada Kesseler | `description` re-scoped to "new logic" + explicit NOT-for exclusions (don't auto-fire on trivial/config/docs/pure-refactor/spike); body verbatim (its 🔴/🌱/🌀 phase emojis double as the harness marker) |
| `diagnose` (+ `scripts/hitl-loop.template.sh`) | mattpocock/skills · `skills/engineering/diagnose` | be55a79 | MIT © Matt Pocock | one line re-pointed: `/improve-codebase-architecture` handoff → **plan mode** (architecture = a design decision here, not an autonomous refactor); + a `STARTER_CHARACTER` marker line (🔬) |
| `verify-before-done` | **blend** — discipline adapted from obra/superpowers · `skills/verification-before-completion` | 6fd4507 | MIT © Jesse Vincent | obra's Iron Law / Gate Function / Rationalization-Prevention spine + our own `make check` / run / verification-report section; + a `STARTER_CHARACTER` marker line (✅) |
| `handoff` | concept from mattpocock/skills · `skills/productivity/handoff` | be55a79 | MIT © Matt Pocock | **reworked**: defined placement (spec `sessions/` or gitignored `.handoffs/`, not OS temp) + structure (Key decisions · **What did NOT work** · Next steps) adapted from conductor-flow `save-history`; kept pocock's suggested-skills + redact + reference-don't-duplicate |

Ours (not vendored): `brainstorm`, `write-plan`, `open-a-pr` — harness-specific. They borrow
*structure* from obra/superpowers (hard-gate, no-placeholders, self-review) but stay our own
because vendoring obra's pipeline verbatim would import its swarm/worktree model.

The MIT and Apache-2.0 notices above satisfy each license's attribution requirement; full
license texts are in each upstream repo.
