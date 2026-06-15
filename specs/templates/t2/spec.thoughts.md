<!-- OPTIONAL planning thread — pairs with spec.md. Stores the decisions + ideas + rejected
     alternatives you iterated through in brainstorm + grill-me (the spec keeps the conclusion;
     this keeps HOW you got there). NOT read by the build. Copy to specs/<slug>.thoughts.md.
     Typed entries (IDEA · DECISION · RESEARCH · QUESTION · CONSTRAINT · INSIGHT), ONE
     chronological number line across both phase sections — so a grilling DECISION can close a
     brainstorm QUESTION by id. -->
# Thoughts — add-rate-limiting

## Brainstorm thread (divergent — the approach)

### [QUESTION 001 · 2026-06-05] What limiting algorithm?
- **What:** token-bucket vs sliding-window-log vs a Redis-backed limiter.
- **Context:** need a polite per-endpoint cap; retry storms hit 4k req/min at one URL.
- **Resolution:** token-bucket (→ DECISION 002).

### [DECISION 002 · 2026-06-05] In-process token-bucket, keyed by host
- **What:** in-memory `dict[host -> TokenBucket]`; no Redis, no DB.
- **Context:** weighed Redis (cross-process) — rejected: no new infra, per-process is enough
  until we scale the sender horizontally. Sliding-window-log rejected: more memory, no gain.
- **Resolution:** token-bucket per destination **host** (not subscriber id) — one bad URL
  shouldn't punish a subscriber's other endpoints. → feeds the spec's *Approach & design*.

## Grilling thread (convergent — the details)

### [DECISION 003 · 2026-06-05] On exhaustion: drop + log, never block
- **What:** skip the send + emit `rate_limited`; keep the batch going.
- **Context:** fail-the-batch was the obvious wrong path — one bad subscriber stalls everyone.
- **Resolution:** drop-and-log. → spec *Resolved decisions*.

### [CONSTRAINT 004 · 2026-06-05] A cap of 0 must be rejected
- **What:** config validation must reject `cap = 0`.
- **Context:** a 0 cap = silent total lockout (outbound-send hotspot).
- **Resolution:** reject at config load. → `reviewer-security` checks this.

### [INSIGHT 005 · 2026-06-05] The retry path is a trap
- **What:** tempting to "fix" retry/backoff while in here.
- **Context:** surfaced while nailing scope — easy to scope-creep into the retry/backoff code.
- **Resolution:** explicitly OUT of scope — don't touch it. → spec *Out of scope*.
