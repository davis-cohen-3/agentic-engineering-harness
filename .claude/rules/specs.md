---
paths:
  - "specs/**"
---

# You're touching a spec — the plan→build handoff

A spec **replaces the human in an autonomous build run**: the builder reads it and cannot ask a
question, so the bar is *survives-your-absence*. The lifecycle and Definition of Ready are owned
by `specs/README.md` (the Ready checklist by the `write-plan` skill) — this rule fires the
load-bearing reminders the moment a spec enters context:

- **Hit an open design point? HARD-STOP and flag it back to plan** — don't design through it
  here. Hand back "blocked: design gap at <X>".
- **Keep `status:` honest** — `ready` means **no open decisions remain**; never flip to `ready`
  over a guess.
- **Conclusion, not journey** — the spec is *what to build*. The planning path stays in this
  worktree's `.workspace/LOG.md` (untracked, not read by the build); repo context is *linked*
  from `docs/`, never pasted in.
- **Which spec this worktree is on is one field** — `.workspace/MISSION.md`'s `spec:`. Editing
  it is the whole mechanism; there is no bind command.
