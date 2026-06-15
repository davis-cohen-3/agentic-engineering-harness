<!-- Sample SCRATCH NOTEPAD — the uncommitted working buffer. In REAL use it is GITIGNORED and
     lives at specs/.context/<slug>.md (one per bound spec); the SessionStart hook auto-creates it
     and re-surfaces its path every start/resume/compact, so working memory survives compaction.
     Shown here co-located + committed ONLY as a worked example. There is NO schema — it is
     fast-and-loose, all-phases (plan→build→test).
     The one rule: it is NEVER a source of truth. Anything durable GRADUATES out (a decision →
     spec.thoughts.md, resume-state → spec.sessions/, a change to what-to-build → spec.md) and
     the notepad is discarded at merge. Contrast spec.thoughts.md: that is committed + curated +
     plan-phase; this is the raw inbox it gets drained from. Copy the spirit, not this comment. -->
# scratch — rate-limit-webhooks  (gitignored, NOT a source of truth)

## plan
- conductor worktree, theme: per-host rate limit on the webhook sender
- gut: token-bucket. checked redis-backed — overkill, no new infra. → graduated to thoughts DECISION 002
- ? cap=0 footgun, who validates → graduated to thoughts CONSTRAINT 004, leave it

## build
- bucket lives in src/util/rate_limiter.py
- TRIED background refill thread first — flaky as hell under the fake test clock, ripped it out.
  lazy refill (compute on read) instead. DON'T reintroduce the timer. → noted in sessions/001
- send() gating seam = top of WebhookSender.send(), before the existing log line
- still need to: confirm the rate_limited event shape matches events.py (don't invent a new one)

## test / wtf
- test_refill_burst flaked twice then passed → it was the timer, gone now
- raw, keep for ref:
    $ make check
    FAIL test_rate_limiter::test_cap_zero_rejected  (cap=0 silently allowed everything)
  ^ that's the CONSTRAINT 004 thing, validation wasn't wired at config load. fixed.
- TODO before /ship: reviewer-security (outbound-send hotspot), verify-before-done = send 1 real webhook
- open thread: do we log host on the rate_limited event too? ask in review, NOT deciding here
