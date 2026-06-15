---
paths:
  - "specs/**"
---

# You're touching a spec — the plan→build handoff

A spec **replaces the human in an autonomous build run**: the builder reads it and cannot ask a
question, so the bar is *survives-your-absence*. The lifecycle and Definition of Ready are owned
by `specs/README.md` (the Ready checklist by the `write-plan` skill) — this rule fires the
load-bearing reminders the moment a spec enters context:

- **Starting work on this spec? Bind the worktree to it** — `make work SPEC=<this-spec-path>`
  (writes the gitignored `.claude/active-spec`) so the `SessionStart` hook re-orients every later
  session (local, resumed, post-compaction) without you re-supplying the path. The hook also
  self-binds from the branch name if you don't; mechanism + fallback live in `specs/README.md`.
- **Keep `status:` honest** — `ready` means **no open decisions remain**; never flip to `ready` over a guess.
- **Conclusion, not journey** — the spec is *what to build*; the planning path goes in
  `<slug>.thoughts.md` (not read by the build), repo context is *linked* from `agent_docs/`
  (never pasted in), and raw in-flight working notes go in the gitignored `.context/<slug>.md`
  scratch notepad — never dumped into the spec.
- **Hit an open design point? Hard-stop and flag it back to plan** — don't design through it here.
