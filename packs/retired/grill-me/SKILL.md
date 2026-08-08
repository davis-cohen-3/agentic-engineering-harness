---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
---

STARTER_CHARACTER = 🔥 — open each reply with it while this skill is active.

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time, waiting for my answer before moving to the next.

If a question can be answered by exploring the codebase, explore it instead of asking me.

## How to grill — techniques
Use these deliberately; each makes a question sharper than a generic "have you considered X?".

- **Sharpen fuzzy language.** When I use a vague or overloaded term, propose a precise canonical
  one and make me pick. "You said 'the job' — do you mean the queued task or the cron entry?
  Those behave differently."
- **Stress-test with concrete scenarios.** Don't argue in the abstract — invent a specific edge
  case that forces precision about a boundary. "Two runs bind the same spec at once — which one
  wins, and what does the second see?"
- **Cross-reference against the code.** When I claim how something works, verify it against the
  codebase before accepting it, and surface contradictions on the spot. "You said the hook
  blocks on the default branch, but `branch-guard.sh` only warns — which is intended?"
- **Challenge against the glossary.** When a term clashes with `agent_docs/glossary.md`, call it
  out and reconcile it before moving on (grounding rule below).
- **Follow the dependency, not the list.** When an answer changes a downstream decision, chase
  that branch next instead of marching through a flat checklist.

## Ground the grilling in this codebase (harness)
Consult `agent_docs/` **on demand — do NOT read it wholesale.** When a question touches an
area you're unsure of, pull the ONE relevant doc (use the `agent_docs/` README index to find
it — `glossary.md` for a term, `architecture.md` for a boundary, etc.). Challenge the plan
against what you find: if a term clashes with the glossary or a step contradicts the
architecture, surface it immediately. Codebase-grounded questions beat generic ones — but
grounding is a targeted lookup per question, not a prerequisite read. (Deep codebase mapping
is the `scout` agent's job, not yours — you interview the user.)

## Record the thread (harness)
As decisions resolve, append them under the **Grilling thread** section of the spec's
`thoughts.md` as `DECISION` entries (and log still-open ones as `QUESTION`); keep the one
chronological number line so a `DECISION` here can close a brainstorm `QUESTION` by id. Shape:
`specs/templates/t2/spec.thoughts.md`. The settled answers also fold into the spec's **Resolved
decisions** — but thoughts.md keeps the *why* and the alternatives you rejected, which the
spec drops.
