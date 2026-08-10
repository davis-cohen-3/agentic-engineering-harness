<!-- Worked spec (a real T2 example). Copy this file to specs/<slug>.md, replace the content,
     delete this comment. Every field pre-answers a question the absent builder would hit; the
     parenthetical labels are the guidance. Collapse to goal+acceptance+one-pointer for T1. -->
---
status: ready        # draft → ready → building → done   (see ../../README.md)
tier: T2             # T0 | T1 | T2 | T3                  (see ../../README.md → Right-sizing)
hotspots: [outbound-send]   # any of: migrations, auth, payments, outbound-send, prod-deploy, spend
---

# Add per-endpoint rate limiting to the outbound webhook sender

## Problem / Solution / User stories   (user-POV intent)
- **Problem:** a single misbehaving subscriber can currently get hammered — retry storms have
  sent 4k req/min at one URL, DoS'ing the subscriber and burning our own egress budget.
- **Solution:** a polite per-destination cap; over the cap we drop-and-log, never fail the
  whole send batch (default-deny is wrong here).
- **Key user stories:**
  1. As a webhook subscriber, I want one bad endpoint of mine to not starve my other endpoints,
     so that a single failing URL doesn't take down the rest of my integration.
  2. As an operator, I want our sender to cap its own outbound rate per host, so that we don't
     DoS a subscriber or blow the egress budget during a retry storm.
  3. As an operator, I want over-cap drops recorded as events, so that throttling is observable
     and never silent.

## Approach & design   (HOW — RESOLVED here; the builder EXECUTES this, never re-decides it)
Chosen approach: in-process token-bucket keyed per destination host. Beats a sliding-window
log (simpler, O(1) memory/host) and a Redis limiter (no new infra; per-process is enough
until we scale the sender horizontally). Keyed by **host, not subscriber id** — one bad URL
shouldn't punish a subscriber's other endpoints.
Key design decisions:
- Data model: in-memory `dict[host -> TokenBucket]`; no schema / DB change.
- Interfaces / contracts: `RateLimiter.allow(host) -> bool`, called by `WebhookSender.send()`
  before dispatch. New event `rate_limited{host, subscriber_id, ts}` mirrors the existing
  `events.py` emission shape.
- Integration points: the ONLY gate point is `WebhookSender.send()`; do not touch the
  retry/backoff path.
- Error & edge handling: lazy refill (compute on read, no timer); a cap of `0` is rejected
  at config load (lockout guard); a missing per-subscriber cap falls back to the global
  default (60/min).
- Test seam & prior art: test at the `WebhookSender.send()` seam (existing, highest — exercises
  the real gate, not the bucket in isolation); mirror `tests/webhooks/test_sender.py::test_retry_backoff`
  for the fake-sink setup. Unit-test the bucket directly only for the refill/burst math.

## Task decomposition   (ordered; note dependencies)
1. Add a token-bucket limiter keyed by destination host (in-memory, per-process)  — deps: none
2. Gate `WebhookSender.send()` on the limiter; on exhaustion, skip + emit a `rate_limited` event — deps: #1
3. Make the cap configurable per subscriber (fallback to a global default)         — deps: #2

## Acceptance criteria   (per task; objective + testable)
- [ ] #1: limiter allows N tokens/sec, refills correctly; unit-tested incl. burst + steady-state
- [ ] #2: a host over its cap is skipped (not sent), the batch continues, one `rate_limited` event/skip
- [ ] #3: a subscriber with a custom cap uses it; one without falls back to the global default
- [ ] no sender throws on rate-limit — it logs and moves on

## Out of scope          (explicit non-goals)
- Distributed/cross-process limiting (in-memory per-process is fine for now)
- Retry/backoff redesign (separate work; don't touch the retry path)
- A UI for editing caps (config only, this pass)

## Risk hotspots touched (migrations / auth / payments / outbound-send / prod-deploy / spend)
- **outbound-send** → engage `reviewer-security`: confirm no message is silently DROPPED
  without an event, and the cap can't be set to 0 by accident (lockout).

## Context pointers      (the files the builder reads/edits to EXECUTE)
- `src/webhooks/sender.py` — `WebhookSender.send()` is the gate point
- `src/webhooks/events.py` — event emission pattern to mirror for `rate_limited`
- `src/util/` — confirmed during planning: no existing limiter, write a new one here

## Verification          (how "done" is PROVEN)
- gate: `make check` (unit tests for #1–#3)
- manual: point two fake subscribers at a local sink, blow past the cap on one, confirm
  the other still receives and the capped one emits `rate_limited` (verify-before-done)

## Resolved decisions    (settled scope/behavior from grilling — do NOT re-litigate;
                          structural choices live in Approach & design above)
- On exhaustion we **drop + log**, never block or fail the batch.
- In-memory per-process is acceptable; revisit only if we scale the sender horizontally.
- Global default cap = **60 req/min**; per-subscriber overrides it.
