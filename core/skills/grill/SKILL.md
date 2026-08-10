---
name: grill
description: >-
  Interview the user relentlessly about a plan, design, or decision until you reach
  shared understanding, resolving each branch of the decision tree one at a time and
  grounding every question in this repository's docs and code. Use when the user wants
  to stress-test a plan or design, or says "grill me" / "grill this" / "stress-test
  this". Precedes write-plan on T3 work.
---

# Grill

STARTER_CHARACTER = 🔥 — open each reply with it while this skill is active.

Interview the user relentlessly about every aspect of this until you reach a shared
understanding. Walk down each branch of the decision tree, resolving dependencies between
decisions one at a time.

**One question per turn.** Wait for the answer before asking the next — several at once is
bewildering and gets you shallow answers to all of them. For each question, give your
recommended answer and the reasoning, so the user is reacting to a position rather than
starting from a blank page.

**Facts are yours; decisions are theirs.** If a question can be answered by reading the code,
the docs, or the filesystem, go and find out instead of asking. Spend the user's attention only
on what genuinely requires their judgment.

**Do not act on the outcome until the user confirms you have reached shared understanding.**

## Techniques

Use these deliberately; each makes a question sharper than a generic "have you considered X?".

- **Sharpen fuzzy language.** When the user uses a vague or overloaded term, propose a precise
  canonical one and make them pick. *"You said 'the job' — do you mean the queued task or the
  cron entry? Those behave differently."*
- **Stress-test with concrete scenarios.** Don't argue in the abstract — invent a specific edge
  case that forces precision about a boundary. *"Two runs bind the same spec at once — which one
  wins, and what does the second see?"*
- **Cross-reference against the code.** When the user claims how something works, verify it
  before accepting it, and surface contradictions on the spot. *"You said the hook blocks on the
  default branch, but `block-default-branch-commit.sh` only warns — which is intended?"*
- **Challenge against the glossary.** When a term clashes with `docs/glossary.md`, say so and
  reconcile it before moving on.
- **Follow the dependency, not the list.** When an answer changes a downstream decision, chase
  that branch next instead of marching through a flat checklist.
- **Separate three things that sound alike:** what the code does *today*, what the product is
  *intended* to do, and what this plan has *decided*. Conflating them is the most common way a
  grilling produces confident nonsense.

## Ground it in this repository

Consult `docs/` **on demand — do NOT read it wholesale.** When a question touches an area you
are unsure of, pull the ONE relevant document via `docs/INDEX.md` (`glossary.md` for a term,
`architecture.md` for a boundary, `adrs/` for why something is the way it is). Challenge the plan
against what you find and surface any clash immediately.

Grounding is a targeted lookup per question, not a prerequisite read. Deep codebase mapping is
the `scout` agent's job — you interview the user.

## Record the thread

Append to `.workspace/LOG.md` as the interview goes, one entry per resolution:

```markdown
DECISION 7 — the spec pointer is a plain field
  Chose: MISSION.md `spec:` holds a repo-relative path.
  Rejected: {path, commit} pinning — drift fires on the builder's own edits.
  Because: rebinding should be editing a field, not running a command.

QUESTION 8 — does a second worktree building the same spec need detection?
```

One chronological number line, so a later `DECISION` can close an earlier `QUESTION` by id.
`LOG.md` keeps the *why* and the rejected alternatives; the spec that `write-plan` produces
keeps only the conclusion. That is the whole reason both exist.

## Promotion: propose, never write

A grilling turns up things that look like durable repository truth — an ADR, a glossary entry, an
architecture correction, an issue worth filing.

**Say so and ask. Never create one silently.**

```
This settled that a worktree is bound to exactly one spec. That reads like an ADR
("one worktree, one spec") and `docs/glossary.md` has no entry for "bind".
Want me to draft either? Neither is written unless you say yes.
```

Documentation is promoted deliberately, by the user, normally at merge and as a separate change —
never as a side effect of a conversation. A skill that writes docs while you are still deciding
produces confident records of decisions that had not actually settled.
