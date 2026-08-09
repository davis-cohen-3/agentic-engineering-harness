> ## ⚠ SUPERSEDED — DO NOT EXECUTE
>
> Adds an unsequenced lint hook and depends on task 01's removed-gate model. Codex hook parity is now task T0.11, which harvests melting's `origin/main` fix.
>
> **Authority:** `DECISIONS-PENDING.md` → `CONTRACT.md` →
> `HARNESS-DEPOT-OPERATIONAL-DESIGN-REVIEW.md` → `plan/tasks.md`.
> Retained as provenance and research. Harvest evidence from it; do not run its instructions.
>
> *Bannered 2026-08-08.*

---
status: superseded
tier: T3
hotspots: []
---

# 02 · Per-edit lint hook + unattended-only Stop hook

> Part of the [harness standardization](./README.md) epic — read its **Shared context** and
> **Epic-level decisions** first.

## Goal
Replace one expensive always-on gate with one cheap always-on check plus one gate that only fires
when nobody is watching. After this run, editing a file lints that file in milliseconds, and
`enforce-gate-on-stop.sh` is silent in every interactive session.

## Approach (resolved at the epic level — execute, don't re-decide)

### New: `.claude/hooks/lint-edited-file.sh` (PostToolUse, matcher `Write|Edit`)
Reads the hook payload from stdin, takes `tool_input.file_path`, dispatches on extension, and
lints **only that one file**. The base ships the dispatch skeleton with the case arms commented
out; an adopting repo fills in its own (task 04 makes this an explicit adoption slot).

```bash
file="$(jq -r '.tool_input.file_path // empty')"   # jq missing -> exit 0, fail open
case "$file" in
  *.py)        out=$(uv run ruff check --fix "$file" 2>&1) || rc=$? ;;
  *.ts|*.tsx)  out=$(npx eslint --fix "$file" 2>&1)        || rc=$? ;;
  *)           exit 0 ;;
esac
```

Rules the implementation must honor:
- **Fail open, always.** Missing `jq`, missing linter, unreadable payload, file outside the repo →
  exit 0 silently. A broken lint hook must never wedge a session.
- **Report via exit 2 with the linter output on stderr.** PostToolUse cannot block the edit — it
  already happened — but exit 2 surfaces stderr to the agent as an error, which is the point:
  fix it now, in context, while the edit is still the subject.
- **Never lint anything but `file_path`.** No directory walks, no `--fix .`, no project-wide run.
  The entire value of this hook is that it is O(1) in repo size.
- **Bound it.** Wrap in `timeout 10` (or the shell equivalent) so a pathological linter can't
  stall the turn.
- **Skip non-source paths** — anything under `.git/`, `node_modules/`, or matching the repo's
  ignore file. Cheapest correct approach: dispatch only on extensions the repo opts into, and let
  the `*)` default exit 0.

### Rewritten: `.claude/hooks/enforce-gate-on-stop.sh`
Three changes, in order of importance:
1. **Gate on `HARNESS_UNATTENDED=1`.** First line of logic: if the variable is not exactly `1`,
   exit 0 immediately. This is set by the sandbox / Warren at clone time, never in an interactive
   shell. Document that in the file header.
2. **Drop `make`.** The `[ -f Makefile ] && grep -q '^check:'` probe is gone. The hook runs the
   command in `HARNESS_UNATTENDED_CHECK` (e.g. `npm run test`), set alongside the flag by whatever
   launched the run. If the flag is set but the command is unset or empty, **exit 0 and say so on
   stderr** — an unattended run with no declared check is a misconfiguration to surface, not a
   reason to block forever.
3. **Reduce `MAX_RETRIES` from 5 to 3.** The platform now overrides a Stop hook after 8 consecutive
   blocks regardless, so our breaker exists only to give up *earlier* than the platform and report
   honestly. 3 attempts is enough to catch a flaky first run without burning a long tail of tokens
   on a genuinely red tree.

Keep unchanged: the per-session attempt counter in `$TMPDIR`, the circuit-breaker message telling
the agent not to claim success, and the tail-40-lines output format.

### Wiring: `.claude/settings.json`
Add the PostToolUse entry for `lint-edited-file.sh` alongside the existing `flag-comment-bloat.sh`
on the `Write|Edit` matcher. The Stop entry is unchanged — the hook self-gates internally, which
is better than a settings-level condition because it travels with the file into the sandbox.

## Task decomposition
1. Write `lint-edited-file.sh` with the dispatch skeleton + fail-open + timeout — deps: none
2. Wire it into `.claude/settings.json` PostToolUse `Write|Edit` — deps: #1
3. Rewrite `enforce-gate-on-stop.sh`: unattended gate, drop `make`, `MAX_RETRIES=3` — deps: none
4. Rewrite `docs/recommended/hooks.md:45` to describe the new two-hook model; delete the stale
   `stop_hook_active` claim (that field is not in the current hooks docs) — deps: #1, #3

## Acceptance criteria
- [ ] #1: piping `{"tool_input":{"file_path":"/tmp/x.py"}}` into the hook with a deliberately
      lint-broken file exits 2 and prints the linter's message on stderr; the same with a clean
      file exits 0 silently; a `.md` path exits 0 silently; a payload with no `file_path` exits 0
- [ ] #1: with `jq` unavailable on `PATH`, the hook exits 0 and prints nothing
- [ ] #2: a real `Edit` to a lint-broken source file in a live session surfaces the linter error
      to the agent in the same turn (observed, not inferred)
- [ ] #3: with `HARNESS_UNATTENDED` unset, the Stop hook exits 0 without running any command —
      confirmed by ending a real interactive turn and observing no delay and no check output
- [ ] #3: with `HARNESS_UNATTENDED=1` and `HARNESS_UNATTENDED_CHECK='false'`, the hook exits 2 with
      the attempt counter, and exits 0 with the circuit-breaker message on the 4th consecutive call
- [ ] #3: with `HARNESS_UNATTENDED=1` and `HARNESS_UNATTENDED_CHECK` unset, exits 0 and warns on stderr
- [ ] #4: `rg -n "stop_hook_active|make check" docs/recommended/hooks.md` returns nothing

## Out of scope
- Filling in real lint commands for any specific language beyond the two commented examples —
  that is per-repo, done in tasks 06–08.
- Any other hook (`block-dangerous-bash.sh`, `protect-secrets.sh`, `block-default-branch-commit.sh`,
  `flag-comment-bloat.sh`, `spec-session-orient.sh`, `collab-reminders.sh`) — all unchanged.
- Deciding *who* sets `HARNESS_UNATTENDED=1`. Warren/burrow integration lives outside this repo;
  the harness's job is to read the flag, and the header comment documents the contract.

## Risk hotspots touched
- **`.claude/hooks/`** is this repo's tuned hotspot — a broken guardrail's blast radius is every
  future run in every repo that inherits it. Engage `reviewer-security` on this diff. Specifically
  confirm: the lint hook cannot execute a path-derived string as a command (the file path is
  attacker-influenceable if a repo contains a hostile filename — quote every expansion), and the
  Stop hook's unattended check cannot run when the variable is merely *set but empty*.

## Context pointers
- `.claude/hooks/enforce-gate-on-stop.sh` — the file to rewrite; keep its counter and breaker
- `.claude/hooks/flag-comment-bloat.sh` — the existing `Write|Edit` PostToolUse hook to sit beside;
  mirror its payload-parsing and fail-open style
- `.claude/settings.json` — hook wiring
- [Hooks reference](https://code.claude.com/docs/en/hooks) — `tool_input.file_path`, exit-2
  semantics, `hookSpecificOutput.additionalContext`

## Verification
- checks: the base's declared checks from task 01, including `scripts/validate-hooks.sh`
  (both new/changed hooks must be executable)
- manual: drive every acceptance criterion above by hand with real payloads and a real session —
  in particular, end an interactive turn and confirm the Stop hook adds no latency
  (`verify-before-done`). This is the run where "it should work" is most tempting and least
  acceptable: a hook that misbehaves is felt on every subsequent turn in every repo.
