<!-- Sub-spec of templates/t3/ (T3, task 02). Narrower than a standalone T2 — shared context is
     in ./README.md. Depends on 01. -->
---
status: draft        # not yet ready: see the open decision below — keeps `status` honest
tier: T3
hotspots: []
---

# 02 · Drain the queue from a background worker

> Part of the [durable webhook delivery](./README.md) epic. **Depends on [01](./01-queue-table.md)**
> (the `webhook_deliveries` table + enqueue). Read the epic's shared context first.

## Goal
A worker polls `webhook_deliveries` for `pending` rows and dispatches them, marking each `sent`
or `failed`. With `WEBHOOK_ASYNC=on`, `send()` stops dispatching inline and only enqueues.

## Approach (resolved at the epic level)
Single-process poller: claim a batch with `SELECT … FOR UPDATE SKIP LOCKED`, reuse the existing
dispatch code path lifted out of `send()`. No retry this pass — a `failed` row simply waits for
task 03.

## Task decomposition
1. Worker loop: claim a batch, dispatch, update row status — deps: 01
2. Flip `send()` to enqueue-only when `WEBHOOK_ASYNC=on` — deps: #1

## Acceptance criteria
- [ ] #1: `pending` rows dispatch and flip to `sent`; a dispatch error flips the row to `failed`
- [ ] #2: with the flag on, `send()` does not dispatch inline (row stays `pending` for the worker)
- [ ] `make check` green

## Out of scope
- Retry/backoff and dead-lettering (task 03); shared-store rate limiting (task 03).

## Open decisions (why this is `draft`, not `ready`)
- Worker lifecycle — standalone process vs. an in-app background thread — is unsettled. **Resolve
  in plan mode before flipping to `ready`;** a build run must not pick this for us.

## Context pointers
- `src/webhooks/sender.py` — the dispatch path to extract and reuse; the flag branch in `send()`
- task 01's `webhook_deliveries` schema

## Verification
- gate: `make check`
- manual: enqueue rows, run the worker, watch them go `pending → sent`; with the flag on confirm
  `send()` only enqueues (verify-before-done)
