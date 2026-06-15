# Coding-agent antipatterns — observed failure modes + harness mitigations

A running log of behaviors we keep seeing in coding agents, and how this harness
tries to mitigate each over time. Harness-author space — **does NOT travel** into
adopting repos (it lives in `docs/`). This is the *why* behind several hooks and
FLOOR rules; mitigations link back here.

How to use it: when you notice the agent doing something wrong *again*, add (or
sharpen) a row. A pattern earns a **mechanism** only once it's demonstrably
forgotten despite being written down — otherwise it stays guidance. Mechanism
choice follows `docs/recommended/hooks.md`: silent/expensive/keep-reminding → a
hook; judgment-only posture → a reminder; everything else → FLOOR/rules.

## Status legend
✅ mitigated · 🟡 partial · ⬜ open (tracked, not yet addressed) · 🧭 by-design (handled elsewhere, e.g. planning)

## Log

| # | Observed behavior | Mechanism | Where | Status |
|---|---|---|---|---|
| 1 | Over-adds fallbacks / defensive code I didn't ask for | candidate FLOOR/rule line | — | ⬜ |
| 2 | Verbose comments / docs (explains the *what*) | FLOOR "minimal comments" + comment-bloat habit hook | `FLOOR.md`, `.claude/hooks/flag-comment-bloat.sh` | ✅ |
| 3 | Reinvents logic the codebase already has | resolved during planning (scope/reuse) | `write-plan` skill, `scout` agent | 🧭 |
| 4 | Picks the complex/sophisticated build over simple+effective | candidate FLOOR/rule line | — | ⬜ |
| 5 | Implements/tests or does more than asked, unprompted | plan-vs-build mode + collab reminder (🛤️ no course change w/o permission) | `FLOOR.md`, `.claude/hooks/collab-reminders.sh` | 🟡 |
| 6 | Spreads scope / loads many domains → context "clouding" | FLOOR "one run, one task" | `FLOOR.md` | 🟡 |
| 7 | Writes too much for me to read; not concise | none yet (kept out of the collab hook by choice) | candidate: personal `~/.claude` or a reminder line | ⬜ |

## Collaboration postures we now inject (from `collab-reminders.sh`, lexler-pattern)
Not in the original 7 — adopted because they're the *relationship* rules that decay
fastest over a long session. One is injected at random per turn:
- 🤝 push back on mistakes; ask when unsure of direction instead of guessing
- 🤲 honest feedback over agreeable; no flattery
- 🛤️ no shortcuts / direction changes without permission (also covers #5)
- ❓ ask questions one at a time

## Notes
- The two hook *families*: build-mode **correctness** gates (`exit 2`, blocking) vs
  these collaboration **relationship** nudges (`exit 0`, additive). See
  `docs/recommended/hooks.md`.
- Don't let this list grow a mechanism per row — most rows should stay guidance.
  The bar for a hook is real friction, not annoyance (the decision filter in
  `docs/recommended/hooks.md`).
