<!-- Sample SCRATCH NOTEPAD for a T1. A T1 skips the COMMITTED companions (no thoughts/sessions —
     nothing to design), but it still gets THIS one: the gitignored scratch notepad is auto-seeded
     by the SessionStart hook for ANY bound spec, every tier. In real use it lives at
     specs/.context/<slug>.md (gitignored) and is discarded at merge — shown here co-located +
     committed only as an example. Even trivial work benefits from a buffer that survives
     compaction. Keep it tiny; it's never a source of truth. -->
# scratch — webhook-log-host  (gitignored, NOT a source of truth)

- one-liner: add host=<dest> to the existing log.info in WebhookSender.send(). log-only.
- found the line: src/webhooks/sender.py, the log.info inside send()
- verify-before-done: sent 1 webhook locally → log now shows host=api.acme.test ✓
- nothing to graduate; merge will drop this file.
