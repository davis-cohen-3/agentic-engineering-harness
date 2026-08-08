<!-- Sample SCRATCH NOTEPAD for a T3 sub-spec. A T3 executes as MULTIPLE build runs (one per
     sub-spec), and the notepad is per BOUND spec — so each sub-spec run gets its own, keyed by
     the slug it's bound to. In real use this is gitignored at specs/.context/01-queue-table.md
     (NOT under the epic folder — the .context/ dir is flat, keyed by slug) and discarded at
     merge; shown here co-located + committed only as an example. Sibling runs (02-worker,
     03-retry-dlq) each get their own. No schema; never a source of truth; graduate durable
     notes into the sub-spec / its thoughts / its sessions. -->
# scratch — 01-queue-table  (gitignored, NOT a source of truth)

## build
- migration: created webhook_deliveries (id, subscriber_id, host, payload, status, attempts, created_at)
- index on (status, created_at) — task 02's worker drains `status='pending' ORDER BY created_at`,
  so this index is load-bearing for THAT run, not this one. flagged it in the sub-spec hotspot note.
- enqueue point = top of send(), behind WEBHOOK_ASYNC=off so dispatch still happens sync this pass

## test / wtf
- raw, migrations hotspot so I actually exercised the rollback:
    $ migrate up && migrate down && migrate up   → clean both ways ✓
- TRIED a partial index `WHERE status='pending'` first — neater, but it complicated 02's planner
  reasoning and the epic README didn't call for it. reverted to the plain composite index.
- still need: reviewer-security on the migration (forward-only + additive + reversible) before handing 02 the green light
- one pending row per send confirmed (sent 1 webhook, row present, sync dispatch still fired) ✓
