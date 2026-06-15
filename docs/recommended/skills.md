# Recommended skills + CLAUDE.md practices

Brief catalog of skills worth adding and the CLAUDE.md principles behind a strong
harness. Sourced from the leaders in `docs/SOURCES.md`. `[ADD]` = recommended,
`[VENDORED]` = upstream copied ~verbatim (attributed in the SKILL footer), `[OURS]` =
harness-specific / Warren-wired (can't be vendored without importing a rival pipeline —
we steal structure, keep our wiring). Don't install everything — Anthropic guidance:
~8–12 skills max before you pay a "context tax." (We're at 8 traveling skills; `adopt-harness`
makes 9 dirs but doesn't travel.)

## Skills worth adding (by job)

Planning / alignment (the #1 failure mode is misalignment *before* code):
- **`[VENDORED]` grill-me** — interrogate YOU one Q at a time until shared understanding;
  explore the codebase instead of asking when possible. Verbatim from `mattpocock/skills`.
- **`[OURS]` brainstorm** — pick the approach (divergent). Harness-wired (T3-only, terminal
  → our `write-plan`/`specs/`); hard-gate pattern stolen from `obra/superpowers` brainstorming.
  We do NOT vendor obra's brainstorming verbatim — it chains to writing-plans + docs/superpowers.
- **`[OURS]` write-plan** — decompose + resolve design into a `specs/` spec. Harness-wired
  (Warren, our DoR); no-placeholders/self-review patterns from `obra/superpowers` writing-plans
  (not vendored — it chains to subagent-driven-development = the swarm we rejected).

Build / test:
- **`[VENDORED]` tdd** — red/green/refactor with predict-then-run discipline; `[TEST]`-comment
  planning, ZOMBIES completeness check, simplify-then-refactor per cycle. Verbatim from
  `lexler/skill-factory` (`output_skills/testing/tdd`, SKILL + `references/zombies.md`).
- **`[ADD]` webapp-testing** — Playwright-driven testing of a local app incl. auth flows
  + JS-rendered content. `anthropics/skills`. (Your tier-3 judgment gate.) PER-REPO: needs
  the app's URL/creds, so it stays an overlay, not base.
- **`[VENDORED]` diagnose** — disciplined bug loop, "build a feedback loop" first. From
  `mattpocock/skills` (`engineering/diagnose`, incl. its `scripts/hitl-loop.template.sh`).
  One re-point: upstream's `/improve-codebase-architecture` handoff → our **plan mode**
  (architecture = a design decision, not an autonomous refactor). Now self-contained.

Refactor / quality:
- **`[BUILTIN]` /simplify** — readability-only refactor of recently-changed code, no behavior
  change. We use the built-in skill instead of vendoring `anthropics/claude-plugins-official`'s
  `code-simplifier` agent (removed): the built-in is maintained and `/code-review --fix` covers
  the same cleanup *plus* bug-finding, so the vendored copy was redundant context tax.
- **`[ADD]` using-git-worktrees** — isolated worktrees w/ safety checks; the standard
  parallel-agent pattern (your post-Conductor path). `obra/superpowers`.
- **`[OURS]` verify-before-done** — evidence-before-claims gate. Spine (Iron Law / Gate
  Function / Rationalization Prevention) adapted from `obra/superpowers`
  verification-before-completion; "In this harness" tail = our `make check` + run + report.

Ship (one observable artifact each — the mark of a good command-skill):
- **`[HAVE]` open-a-pr / `/ship`** — this harness's PR skill + thin command.
- **`[ADD]` /commit** — analyze diff → Conventional Commit. Set `disable-model-invocation:
  true` + `allowed-tools: git add, git commit, git status` so only you trigger it.

Token economy (optional):
- **`[ADD]` caveman / terse-mode** — strips narration, keeps code/facts; big output-token
  cut. Keep a safety carve-out for destructive-op warnings. `mattpocock/skills` (`/caveman`).

Agentic-app-specific:
- **`[PERSONAL]` write-a-skill** — author new skills with best-practice structure +
  description-trigger precision + progressive disclosure. From `mattpocock/skills`. REMOVED from
  this base floor: skill-authoring isn't a job product repos (which inherit this) ever do — it
  belongs in the harness-author's `~/.claude`, not every fork's context budget.
- **`[OURS]` handoff** — compact the conversation into a handoff doc (Key decisions · **What
  did NOT work** · Next steps · suggested-skills); references artifacts by path, redacts secrets.
  Concept from `mattpocock/skills`, **reworked** with a defined placement (spec `sessions/` if a
  spec exists, else gitignored `.handoffs/` — NOT OS temp) + structure from conductor-flow
  `save-history`. KEPT (not pipeline-wired) because it fills a gap the spec doesn't: spanning
  **multiple chat sessions within one spec/issue** — the spec is the plan→build handoff; this
  carries mid-execution session-to-session state.
- **`[ADD]` mcp-builder** — scaffold a typed MCP server (relevant when your app exposes
  its own tools). `anthropics/skills`.

## CLAUDE.md best practices (source: HumanLayer "Writing a good CLAUDE.md")

- **It's an instruction budget, not a doc.** Models follow ~150–200 instructions reliably;
  CC's system prompt already spends ~50. Keep yours to the few universally-applicable rules.
  Claude ignores parts it deems irrelevant — noise actively costs you.
- **Length:** under ~100 lines is good, ~300 is the outer bound. HumanLayer's own is <60.
- **WHAT / WHY / HOW:** WHAT = stack + structure map (critical in monorepos); WHY = purpose;
  HOW = build/test/verify commands.
- **Progressive disclosure:** thin CLAUDE.md that *references* a docs dir (architecture,
  testing, conventions) — load on demand, same principle as skills. The folder name is an
  arbitrary community convention (`docs/`, `ai_docs/`, `.agent/`); nothing is magic about it.
- **Document anti-patterns you've actually hit** — highest-value, most-underused section.
  Grow it from real mistakes, not speculation.
- **Leave out:** lint/style rules (a linter's job), framework knowledge Claude has, command
  dumps, stale history, and never secrets. Avoid raw `/init` output — handcraft.

## Format note (CC v2.1.101+, Apr 2026)
Slash commands merged into skills. `.claude/commands/` still works, but
`.claude/skills/<name>/SKILL.md` is recommended — gives `/name` invocation *plus*
autonomous trigger. Keep each SKILL.md to process steps under ~500 words.

## Patterns adopted / worth adopting from the leaders
- **Visible alignment markers** (lexler) — **ADOPTED, full.** Every skill declares a
  `STARTER_CHARACTER`; the `CLAUDE.md` "Skill markers" rule says open each reply with the
  active skill's marker. Confirms at a glance which skill loaded (and, for `tdd`, which phase).
  Markers: 🧠 brainstorm · 🔥 grill-me · 📐 write-plan · 🔴🌱🌀 tdd · 🔬 diagnose · ✅ verify-before-done · 🚢 open-a-pr · 🤝 handoff.
- **User-reminders hook** (lexler) — *candidate.* A `UserPromptSubmit` hook re-injects 2–5
  critical rules each turn to fight context-rot. (Logged in `docs/recommended/hooks.md`.)
