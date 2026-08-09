> ## ⚠ SUPERSEDED — DO NOT EXECUTE
>
> **Void.** Decision G removed E2E from the harness contract entirely — it fails the portability test. smoke-screen keeps its own `e2e-test` skill.
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

# 03 · `/e2e` skill + trim `verify-before-done`

> Part of the [harness standardization](./README.md) epic — read its **Shared context** and
> **Epic-level decisions** first.

## Goal
Make end-to-end verification something the user invokes, never something an agent decides to do.
After this run, `/e2e` exists as a manual-only skill and `verify-before-done` asks for the
*cheapest real* exercise of the changed path rather than a full app launch.

## Approach (resolved at the epic level — execute, don't re-decide)

### New: `.claude/skills/e2e/SKILL.md`
```yaml
---
name: e2e
description: >-
  Drive the running app end-to-end to prove a change works from the user's side...
disable-model-invocation: true
---
```
`disable-model-invocation: true` is the load-bearing line. It is the documented flag "for workflows
with side effects that you want to trigger manually" — with it set, the model cannot auto-fire the
skill; only `/e2e` does. This is enforcement, not a request, and it is the whole reason this task
exists. **Do not omit it and do not soften it to a prose instruction.**

`STARTER_CHARACTER = 🎭`.

Content, in order:
1. **Preconditions** — the app must be running; if it isn't, launch it per the repo's `AGENTS.md`
   and say so. If it can't be launched, stop and report; do not simulate the flow.
2. **Targets (the adoption slot)** — a `<FILL>` block for the repo: base URL (local and preview),
   test credentials **by env-var name only, never a value**, and where results go. This is the
   content lifted out of `docs/OVERLAY-CONTRACT.md` slot 4, which task 01 deleted from the contract.
3. **Drive it** — prefer the repo's own e2e runner if it has one (`npm run test:e2e`, `playwright
   test`) over hand-driving a browser. Only hand-drive when there's no suite or when reproducing a
   specific reported symptom. Note the cost footgun already recorded in `docs/recommended/mcps.md`:
   browser work via MCP runs ~114k tokens vs ~27k via the Playwright CLI, and the Playwright team
   recommends the CLI for coding agents — so reach for the CLI first.
4. **Evidence** — what to capture: the flow exercised, what was observed at each step, screenshots
   or the runner's output. Same evidentiary bar as `verify-before-done`, applied to a user journey.
5. **Failure** — a failing e2e is a finding, not a retry loop. Report it with the evidence; do not
   iterate silently.

### Trimmed: `.claude/skills/verify-before-done/SKILL.md`
Keep verbatim — this is vendored discipline from obra/superpowers and it is the part that works:
the Iron Law, the 5-step Gate Function, the "Common failures" table, the "Red flags" list.

Change only the "In this harness" section:
- **Step 1** already became "run this repo's checks" in task 01. Leave it.
- **Step 2** currently reads "launch the app / service and run the affected path — however this
  repo runs… the real user path, not a stand-in." Rewrite to: *exercise the changed path the
  cheapest way that is still real* — call the function, hit the endpoint with `curl`, run the CLI
  command, execute the test that covers it. For a bug fix, reproduce the original failure first,
  then show it gone. Add one line: **a full user-journey run through the live app is `/e2e`, which
  the user invokes — do not launch the app to satisfy this step.**
- **Steps 3–5** (check against the spec, verification report, "could not run it → stop") unchanged.

### `VENDORED.md`
Update the `verify-before-done` row's "local changes" cell to describe the new split. The row is a
provenance record — it must stay accurate about what we changed relative to obra's original.

## Task decomposition
1. Write `.claude/skills/e2e/SKILL.md` with `disable-model-invocation: true` + the `<FILL>` targets block — deps: none
2. Trim step 2 of `verify-before-done`; add the `/e2e` handoff line — deps: #1
3. Update the `verify-before-done` row in `.claude/skills/VENDORED.md` — deps: #2
4. Add `/e2e` to the skill inventory in `README.md` and `docs/recommended/skills.md`, with the
   anti-bloat justification (it removes always-on text rather than adding it) — deps: #1

## Acceptance criteria
- [ ] #1: `/e2e` appears in the slash-command picker in a fresh session
- [ ] #1: the skill does **not** auto-fire — in a session where an implementation is finished and
      `verify-before-done` runs, `/e2e` is not invoked and its 🎭 marker never appears. Verify by
      completing a real small change end-to-end, not by reading the frontmatter.
- [ ] #1: no credential *values* appear anywhere in the skill — only env-var names
- [ ] #2: `rg -n "launch the app" .claude/skills/verify-before-done/SKILL.md` returns nothing
- [ ] #2: the Iron Law, Gate Function, Common-failures table and Red-flags list are byte-identical
      to their pre-change content (`git diff` shows changes confined to the "In this harness" section)
- [ ] #3: VENDORED.md's `verify-before-done` row describes the split accurately
- [ ] #4: skill count in `docs/recommended/skills.md` is updated and still within the stated cap

## Out of scope
- Filling in real URLs, credentials or runners for any specific repo — that is tasks 06–08.
- Adding a Playwright or Browserbase MCP server to `.mcp.json`. The skill names the *approach*;
  wiring a server is a per-repo decision and `docs/recommended/mcps.md` already carries the
  rationale and the cost warning.
- The `diagnose` skill's existing mentions of e2e and headless-browser scripts — that skill is
  vendored and its browser step is a debugging technique, not a completion gate. Leave it.

## Risk hotspots touched
None directly, but note: the `/e2e` targets block is where credentials would be pasted by a careless
adopter. The `<FILL>` must say **env-var name only** in the template text itself, and
`.claude/hooks/protect-secrets.sh` still covers the write path.

## Context pointers
- `.claude/skills/verify-before-done/SKILL.md` — the "In this harness" section is the only edit
- `.claude/skills/VENDORED.md` — the provenance row to update
- `docs/OVERLAY-CONTRACT.md` — slot 4's content, deleted by task 01; recover it from
  `git show HEAD~1:docs/OVERLAY-CONTRACT.md` if task 01 already landed
- `docs/recommended/mcps.md:33-37` — the Playwright CLI-vs-MCP cost finding to cite
- `.claude/skills/open-a-pr/SKILL.md` — the shape to mirror for a `/`-invoked skill

## Verification
- checks: the base's declared checks from task 01
- manual: run `/e2e` in a session and confirm it loads and opens with 🎭; then complete an
  unrelated small change and confirm the skill stays silent throughout (`verify-before-done`).
  The negative case — that it does *not* fire on its own — is the acceptance criterion that
  matters most here, and it can only be established by observation.
