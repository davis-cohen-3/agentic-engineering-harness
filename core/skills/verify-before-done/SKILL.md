---
name: verify-before-done
description: >-
  Use after writing code and BEFORE claiming a task is done or opening a PR.
  The agent must actually RUN the change, exercise the behavior, and report
  evidence — not just confirm it compiles. Trigger whenever finishing an
  implementation, "is this done", "verify this works", before /ship.
---

# Verification Before Completion

STARTER_CHARACTER = ✅ — open each reply with it while this skill is active.

Claiming work is complete without verification is dishonesty, not efficiency.
**Core principle: evidence before claims, always.** Violating the letter of this rule
is violating the spirit of it.

## The Iron Law
```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```
If you haven't run the verification in this message, you cannot claim it passes.

## The Gate Function
```
BEFORE claiming any status or expressing satisfaction:
1. IDENTIFY: what command/action proves this claim?
2. RUN:      execute it FULLY (fresh, complete)
3. READ:     full output, check exit code, count failures
4. VERIFY:   does the output confirm the claim?
                - if NO: state the actual status with evidence
                - if YES: state the claim WITH evidence
5. ONLY THEN: make the claim
Skip any step = lying, not verifying.
```

## Common failures (what's required vs not sufficient)
| Claim | Requires | NOT sufficient |
|-------|----------|----------------|
| Tests pass | test output: 0 failures | a previous run, "should pass" |
| Build succeeds | build: exit 0 | "linter passed", logs look fine |
| Bug fixed | reproduce original symptom → gone | code changed, assumed fixed |
| Regression test works | red→green cycle verified | it passes once |
| Requirements met | line-by-line checklist vs the plan | tests passing |

## Red flags — each excuse, and why it fails
These phrases mean STOP — you're about to claim without evidence:
- "should" / "probably" / "seems to" / "should work now" → a prediction isn't evidence; RUN it
- "I'm confident" → confidence ≠ evidence
- expressing satisfaction before verifying ("Great!", "Done!") → no claim before the command
- "just this once" / tired and want it over → no exceptions
- "linter passed" → linter ≠ compiler
- "agent said success" / trusting a subagent's report → verify independently
- "partial check is enough" → partial proves nothing

## In this harness — what "verify" concretely means here
1. **Gate:** run `make check`. If it fails, you're not at verify yet — fix it.
2. **Run it for real:** launch the app / service and run the affected path — however this
   repo runs (its documented launch / dev command) — and exercise the SPECIFIC behavior the
   spec asked for: the real user path, not a stand-in. For a bug fix, reproduce the ORIGINAL
   failure first, then show it's gone.
3. **Check against the spec:** walk the acceptance criteria + plan line-by-line. Anything
   not done or done differently → say so. Don't silently drop or expand scope.
4. **Report:** produce a VERIFICATION REPORT — what you ran · what you observed (evidence
   the human can check without re-running) · plan items done/changed/skipped (with why) ·
   gaps you did NOT verify. This report becomes the PR body, so review is design-approval,
   not bug-hunting.
5. **Could not run it?** Say so plainly and STOP — do not claim done. (In an autonomous
   run, hand back "blocked: could not verify <X>".)
