<!-- Worked T3 epic — the example of DECOMPOSITION. A T3 is bigger than one build run, so it
     becomes a FOLDER: this index (shared context + ordered task list + status rollup) and one
     sub-spec per build-run-sized task (01-, 02-, …). Copy the folder to specs/<epic>/ and
     adapt. Each sub-spec is NARROWER than a standalone T2 — it links back to this index for
     shared context instead of restating it (single-source). One run builds one sub-spec; the
     epic is never built in a single run. -->
# Epic: durable webhook delivery pipeline

**Why:** the in-process sender — and its per-process rate limiter (see [../t2/spec.md](../t2/spec.md))
— can't survive a restart or scale past one process: in-flight sends are lost on deploy and caps
don't coordinate across workers. This epic makes delivery durable and cross-process. It's a T3
because it spans a migration, a new worker, and a limiter rewrite — too much for one build run, and
the pieces must land in order.

## Shared context (linked ONCE here; sub-specs point back, never restate)
- `agent_docs/architecture.md#webhooks` — current sender shape
- `src/webhooks/sender.py` — `WebhookSender.send()`, today's synchronous dispatch
- `src/webhooks/events.py` — the event-emission pattern to mirror
- ADR `agent_docs/adr/0007-durable-webhooks.md` — why a DB-backed queue over a broker

## Tasks (ordered; each is ONE build run)
| #  | Sub-spec                          | Deps | Hotspots      | Status |
|----|-----------------------------------|------|---------------|--------|
| 01 | [queue table + enqueue](./01-queue-table.md)        | —  | migrations    | ready |
| 02 | [worker drains the queue](./02-worker.md)           | 01 | —             | draft |
| 03 | [shared-store limit + retry/DLQ](./03-retry-dlq.md) | 02 | outbound-send | draft |

## Sequencing & integration
This epic executes as **three separate build runs** — one per sub-spec, dispatched 01 → 02 → 03
in dependency order, each in its own isolated worktree/sandbox on its own branch/PR. The
orchestrator threads each run's output into the next (01's schema is in place before 02's worker
run starts). Concretely: 01 lands the schema + enqueue behind `WEBHOOK_ASYNC=off` (writes a row,
still dispatches inline — no behavior change); 02 turns on async dispatch via the worker; 03 moves
the T2 limiter's state into the shared store and adds retry + dead-letter. Each is independently
mergeable and verifiable on its own.

## Epic-level decisions (settled once; sub-specs inherit, don't re-litigate)
- DB-backed queue, not a message broker — no new infra (ADR 0007). Revisit above ~1k sends/s.
- Roll out behind a `WEBHOOK_ASYNC` flag: 01–02 dark-launch, 03 flips it on.
- The per-host cap semantics from the T2 work are preserved — 03 changes only *where the state
  lives* (shared store), not the policy.

## Binding a build run to a sub-spec
Each run sets its pointer to the specific sub-spec, not this index:
`echo specs/<epic>/01-queue-table.md > .claude/active-spec` (see ../../README.md).
