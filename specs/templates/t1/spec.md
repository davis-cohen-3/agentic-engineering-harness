<!-- Worked T1 spec — the FLOOR of how little is enough. A T1 is small with an OBVIOUS approach,
     so it collapses to goal + acceptance + one pointer: no design section, no decomposition,
     no thoughts/sessions companions (nothing to design, one run does it) — though the gitignored
     scratch notepad still applies to every tier (see spec.context.md). Copy to
     specs/<slug>.md. The moment there's a real design fork or >1 ordered task, it's a T2
     (../t2/spec.md), not a padded T1. -->
---
status: ready        # draft → ready → building → done   (see ../../README.md)
tier: T1             # T0 | T1 | T2 | T3                  (see ../../README.md → Right-sizing)
hotspots: []         # none here; if a hotspot IS touched it never scales down — see CLAUDE.md
---

# Add the destination host to the webhook send log line

**Goal:** `WebhookSender.send()` logs each dispatch but omits the destination host, so delivery
and throttling logs can't be filtered by host. Add `host=<dest>` to the existing log line —
log-only, no behavior change.

**Acceptance:**
- [ ] every send log line includes `host=<dest>`; `make check` green
- [ ] nothing else changes (no new events, no control-flow change)

**Pointer:** `src/webhooks/sender.py` — the existing `log.info(...)` call inside `send()`.

**Verification:** send one webhook locally, confirm the host appears in the log line
(verify-before-done).
