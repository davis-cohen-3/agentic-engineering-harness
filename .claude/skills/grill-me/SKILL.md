---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
---

STARTER_CHARACTER = 🔥 — open each reply with it while this skill is active.

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time.

If a question can be answered by exploring the codebase, explore the codebase instead.

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
