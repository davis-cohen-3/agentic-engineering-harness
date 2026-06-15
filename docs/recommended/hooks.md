# Recommended hooks — for agentic-app development

Brief summaries of hooks worth adding when the codebase you're building is *itself* an
agent (job-search agent, SMB AI-workspace). Catalog, not implementations — wire the ones
that match a real hazard. `[HAVE]` = already in this harness, `[ADD]` = recommended.

## The 3 jobs a hook does
```
PreToolUse   → GUARDRAIL   stop the dangerous thing (only event that blocks a tool)
PostToolUse  → REFLEX      auto-fix the small thing (cannot block; runs after)
Stop         → GATE        don't claim "done" until green
```

## ⚠ Warren-survival rule: guardrails must be HOOKS, not permission rules
Verified against burrow v0.3.11: a Warren run spawns `claude --dangerously-skip-permissions`
in the sandbox. **That kills the permission system — `settings.json` `permissions:` allow/deny
rules are DEAD inside a Warren run.** But HOOKS are a separate channel and **still fire**
(PreToolUse + Stop). So: **any guardrail that must survive an autonomous Warren run has to be
expressed as a hook, never as a permission rule.** (This harness's `block-default-branch-commit.sh`
already complies — it's a hook.) Also: burrow defaults `[sandbox] network = none`; if `make check`
needs network, set `network = "restricted"` + `allowed_domains` or the gate false-reds.

## Mechanics that bite (verified vs code.claude.com/docs/en/hooks)
- **Block with `exit 2`, never `exit 1`.** exit 1 = non-blocking warning → the dangerous
  command still runs. Security gates must `exit 2` (or emit `permissionDecision:"deny"`).
- **`exit 2` feeds back stderr, ignores stdout.** JSON decisions are only read on `exit 0`.
- **Stop hooks: check `stop_hook_active` → `exit 0` immediately if true.** Else infinite
  loop + burned tokens. The single most-cited hook mistake.
- Richer path: `exit 0` + stdout JSON `hookSpecificOutput.permissionDecision:"allow"|"deny"|"ask"`,
  can rewrite the call (`updatedInput`) or inject `additionalContext`.

---

## A. Universal guardrails (every app)

- **`[HAVE]` Block commit/push on default branch** — PreToolUse(Bash). exit 2 on
  commit/push while on `master`/`main`. → `block-default-branch-commit.sh`.
- **`[ADD]` Block dangerous Bash** — PreToolUse(Bash). Match `tool_input.command` against
  `rm -rf /|~|$HOME`, `sudo rm`, `curl|sh`, `chmod 777`, `git reset --hard origin`,
  `git push --force … main`, `DROP/TRUNCATE TABLE`. exit 2.
- **`[ADD]` Protect secrets** — PreToolUse(Read|Edit|Write). Deny on `.env*`, `.git/*`;
  scan contents for AWS/GitHub/Stripe/OpenAI/Anthropic key patterns. exit 2.
- **`[ADD]` Format-on-edit** — PostToolUse(Edit|Write|MultiEdit). Dispatch by extension:
  prettier/biome → ts/js, ruff → py, gofmt → go. Keeps tier-0 of the gate always green.
- **`[ADD]` Run the gate on Stop** — Stop. Run `make check`; `exit 2` to force the agent to
  fix instead of stopping. Guard with `stop_hook_active`. This is what gives the gate teeth.

## B. Agentic-app-specific (the prompt-as-source-code layer)

These reuse proven plumbing (path-protection from `.env`, the Stop-gate from test suites),
pointed at surfaces the community hasn't standardized. This is the real edge for your apps.

- **`[ADD]` Treat prompts as source** — PreToolUse(Edit|Write) on `prompts/**`,
  `tool-schemas/**`. Don't block; inject `additionalContext` flagging high blast radius
  (an edit here silently changes *product behavior*, invisibly to tests).
- **`[ADD]` Prompt change → run evals** — Stop or PostToolUse. If `prompts/**` changed this
  session and the eval suite hasn't run, block "done" until it does. Highest-value custom
  hook for an agentic product, where the prompt *is* the source code. **Deferred:** the `evals/`
  scaffold was scoped out of the base (inert, no consumer yet) — an adopting repo that builds an
  eval suite re-introduces it and wires this hook to it.
- **`[ADD]` Provider-secret firewall** — secret scan covering OpenAI/Anthropic keys before
  anything reaches the API. Off-the-shelf: `coo-quack/sensitive-canary`,
  `mintmcp/agent-security` (gitleaks/TruffleHog rule sets).
- **`[ADD]` Loop/cost safety** — PreToolUse on the agent run command. Require a
  `--dry-run`/mock-provider flag in dev so test-running the agent loop doesn't burn real
  tokens or hit live providers.
- **`[ADD]` PII guard (work app)** — PreToolUse. Block test runs pointed at prod data stores
  / real customer data (SMB-workspace hazard).

## C. Ergonomics / from the leaders (see docs/SOURCES.md)

- **`[ADD]` User-reminders** (lexler) — UserPromptSubmit. Re-inject 2–5 *critical* rules as
  `<reminder>…</reminder>` each turn to fight context-rot (e.g. "push back on mistakes,"
  "ask one question at a time"). Treat reminder space as extreme premium — 2–5 rules max.
- **`[ADD]` Habit Hooks** (lexler) — deterministic script detects a trigger (duplication,
  oversized function/file/diff, lint error) and injects a precise prompt *only at that moment*,
  instead of front-loading style rules the agent forgets. Optionally blocking w/ a snooze.
- **`[ADD]` Notification** — TTS / sound / Slack ping when Claude needs you or finishes a turn.

## Decision filter — add a hook only when one is true
1. The failure is **silent** (no error, just wrong behavior — e.g. prompt drift).
2. The failure is **expensive** (leaked key, dropped prod table, burned tokens, PII).
3. You keep **reminding** the agent of the same rule.
Otherwise leave it as guidance in `CLAUDE.md` — hooks cost friction + maintenance.

## Sources
- Docs: code.claude.com/docs/en/hooks · code.claude.com/docs/en/hooks-guide
- `hesreallyhim/awesome-claude-code` (umbrella list) · `disler/claude-code-hooks-mastery`
  (reference impl) · `rohitg00/awesome-claude-code-toolkit` (bash recipes) ·
  `ryanlewis/claude-format-hook` (formatter) · `karanb192/claude-code-hooks` (safety tiers)
