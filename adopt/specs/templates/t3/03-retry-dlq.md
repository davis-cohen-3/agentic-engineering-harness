<!-- Sub-spec of templates/t3/ (T3, task 03). Narrower than a standalone T2 — shared context is
     in ./README.md. Depends on 02. Ties back to the T2 limiter in ../t2/spec.md. -->
---
status: draft
tier: T3
hotspots: [outbound-send]
---

# 03 · Shared-store rate limit + per-subscriber retry & dead-letter

> Part of the [durable webhook delivery](./README.md) epic. **Depends on [02](./02-worker.md)**
> (the worker). Read the epic's shared context first.

## Goal
Move the per-host rate limiter (from [../t2/spec.md](../t2/spec.md)) off per-process memory into
the shared store so caps coordinate across workers, and add bounded retry with a dead-letter for
rows that exhaust their attempts.

## Approach (resolved at the epic level)
Limiter state → the DB; the worker honors the cap when it claims a batch (atomic, so two workers
share one cap rather than one cap each). A `failed` row retries with exponential backoff up to N
attempts; past N it's marked `dead` and emits a `webhook_dead_lettered` event. Per-subscriber caps
and the global default carry over unchanged from the T2 work — only the storage moves.

## Task decomposition
1. Move limiter state to the shared store; worker honors the cap on claim — deps: 02
2. Retry-with-backoff on `failed`; dead-letter past N attempts + emit the event — deps: #1

## Acceptance criteria
- [ ] #1: two workers against one host share a single cap (combined rate ≤ cap), not a cap each
- [ ] #2: a row retries up to N, then goes `dead` with exactly one `webhook_dead_lettered` event
- [ ] no row ends without `sent`, `dead`, or an emitted event; `make check` green

## Risk hotspots touched
- **outbound-send** → engage `reviewer-security`: every terminal row emits an event (no silent
  drops), backoff cannot hot-loop, and the shared cap can't be set to 0 (lockout — same guard the
  T2 spec enforces).

## Context pointers
- the T2 limiter: [../t2/spec.md](../t2/spec.md) *Approach & design* — the state that moves to the
  shared store (its policy is unchanged)
- `src/webhooks/events.py` — mirror this shape for `webhook_dead_lettered`

## Verification
- gate: `make check`
- manual: run two workers against one capped host and confirm the combined rate stays under the
  cap; force repeated failures to exhaust retries and confirm one dead-letter event and zero
  silent drops (verify-before-done)
