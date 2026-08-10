---
name: handoff
description: Compact the current conversation into a handoff document so a fresh agent (or you, later) can resume where this left off. Use at ~60% context usage, before starting a new chat, or after completing significant work.
argument-hint: "What will the next session focus on?"
---

# Handoff — save session state for a clean resume

STARTER_CHARACTER = 🤝 — open each reply with it while this skill is active.

Write a handoff doc that lets a fresh agent continue without re-deriving everything. Capture
**state and decisions, not the conversation**.

## Where it goes (defined — never OS temp)
- **If the work has a spec** (a `specs/<slug>.md` for what you're building): save to
  a `.workspace/history/` record. Do NOT pick the filename yourself — run
  `workspace-record handoff <slug>`, which creates it atomically and prints the path,
  `<summary>` = 3–5 word kebab-case. **Committed** — part of the durable work record, travels
  so two sessions writing in the same second cannot overwrite each other's record.
- **Otherwise:** `.handoffs/<YYYY-MM-DD>-<slug>.md` (**gitignored** — your personal resume notes).

## What to write
```markdown
# Session: <brief summary>
**Date:** YYYY-MM-DD   **Branch:** <branch>

## Summary
<2–3 sentences: what got done this session>

## Key decisions
- <decision + why X over Y>
  (if these came from planning, they also live in `.workspace/LOG.md` — link, don't duplicate)

## What did NOT work   ← the most important section
- <approach tried + why it failed / the dead end>.
  Future sessions WILL re-try failures that aren't written here. This section is why the doc exists.

## Code changes
- created / modified / deleted: <paths>   (paths, not snippets)

## Open questions / blockers
- <unresolved>

## Next steps
- [ ] <pending work to resume>

## Suggested skills
- <skills the next agent should invoke to continue>
```

## Rules
- **Reference, don't duplicate.** Point at the spec, PR, diff, ADRs, `.workspace/LOG.md` by path/URL —
  don't copy their content in.
- **Redact secrets** — API keys, passwords, PII.
- **State, not transcript** — paths/decisions/what-didn't-work, not the back-and-forth or verbose logs.
- If the user named a focus for the next session, tailor **Next steps** to it.

## Sync `MISSION.md` first

Immediately **before** writing the history record, bring `.workspace/MISSION.md` up to date —
current position, next action, blockers. You are the owner of this write (CONTRACT §2), and it
rides an action you already chose to take.

Do it first, not after: the record you are about to write is immutable, and a mission that
disagrees with it is the thing the next session trips over. There is deliberately no "at session
end" obligation — a SessionEnd hook can fire after the model can no longer act.
