<!-- Sub-spec of templates/t3/ (T3, task 01). NARROWER than a standalone T2: shared context lives
     in ./README.md — link to it, don't restate. One build run executes this file. -->
---
status: ready        # this sub-spec is ready; the epic as a whole is still in progress
tier: T3
hotspots: [migrations]
---

# 01 · Add the `webhook_deliveries` queue table + enqueue on send

> Part of the [durable webhook delivery](./README.md) epic — read the epic's **Shared context**
> and **Epic-level decisions** first; this sub-spec assumes them and does not repeat them.

## Goal
Persist every outbound webhook as a row so the worker (task 02) can drain it. Enqueue-only this
pass: `send()` writes a `pending` row AND still dispatches synchronously while `WEBHOOK_ASYNC=off`,
so there is no observable behavior change yet.

## Approach (resolved at the epic level — execute, don't re-decide)
New `webhook_deliveries` table: `id, subscriber_id, host, payload, status, attempts, created_at`.
`WebhookSender.send()` inserts a `pending` row before its existing dispatch. Forward-only,
additive migration; no backfill (only new sends are enqueued).

## Task decomposition
1. Migration: create `webhook_deliveries` + index on `(status, created_at)` — deps: none
2. Enqueue a `pending` row in `send()` before dispatch (flag-gated) — deps: #1

## Acceptance criteria
- [ ] #1: migration applies AND rolls back cleanly on a scratch DB
- [ ] #2: each send writes exactly one `pending` row; sync dispatch is unchanged with the flag off
- [ ] `make check` green

## Out of scope
- Draining/dispatching the queue (task 02) and retries/dead-letter (task 03).

## Risk hotspots touched
- **migrations** → engage `reviewer-security`: confirm forward-only + additive + reversible, and
  that the `(status, created_at)` index covers the worker's `status='pending' ORDER BY created_at`
  claim path (task 02 depends on it).

## Context pointers
- `db/migrate/` — migration location + naming (mirror the latest one)
- `src/webhooks/sender.py` — the insert point at the top of `send()`

## Verification
- gate: `make check` (migration + enqueue unit tests)
- manual: migrate up/down on a scratch DB; send one webhook, confirm a `pending` row exists AND
  dispatch still happened (verify-before-done)
