<!-- Sample mid-build handoff (written by the `handoff` skill). Lives at
     specs/<slug>.sessions/NNN_<summary>.md — committed, carries session-to-session state
     WITHIN one spec. NNN is the next number (ls the dir; start 001). Copy the structure,
     not this comment. -->
# Session: rate-limiter — bucket landed, gating next

**Date:** 2026-06-05   **Branch:** rate-limit-webhooks

## Summary
Implemented task #1 of `spec.md` — the per-host token-bucket limiter (`src/util/rate_limiter.py`)
with refill/burst unit tests green. Tasks #2 (gate `send()`) and #3 (per-subscriber config)
are untouched.

## Key decisions
- Lazy refill (compute tokens on read, no background timer) — simpler, deterministic in tests.
  (Structural rationale lives in `spec.md` *Approach & design* — not duplicated here.)

## What did NOT work   ← the most important section
- First cut used a background refill thread — flaky under the test clock and pointless for an
  in-process limiter. Abandoned for lazy refill. **Do not reintroduce a timer.**

## Code changes
- created: `src/util/rate_limiter.py`, `tests/util/test_rate_limiter.py`
- modified: none yet (`WebhookSender.send()` gating is task #2)

## Open questions / blockers
- None. The `send()` seam and the `rate_limited` event shape are already resolved in `spec.md`.

## Next steps
- [ ] Task #2: gate `WebhookSender.send()` on `limiter.allow(host)`; on exhaustion skip + emit
      `rate_limited` (mirror `events.py`). Reproduce-then-verify per `verify-before-done`.
- [ ] Task #3: per-subscriber cap with fallback to the 60/min default.

## Suggested skills
- `tdd` (tasks #2–#3 are new behavior), then `verify-before-done` + `reviewer-security`
  (outbound-send hotspot) before `/ship`.
