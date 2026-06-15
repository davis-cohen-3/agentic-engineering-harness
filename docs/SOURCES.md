# Sources — people & repos leading agentic-coding DevEx

The master "who to steal from" index. Track these; the per-touchpoint catalogs
(`docs/recommended/{skills,agents,hooks,mcps}.md`) pull concrete patterns from here.

## People

- **Jesse Vincent** (`@obra`) — github.com/obra/superpowers · blog.fsck.com.
  Author of **Superpowers**, the de-facto reference skills framework (brainstorm →
  plan → TDD → verify). The canonical "what a good skill looks like."
- **Dexter Horthy** (HumanLayer) — humanlayer.dev/blog · github.com/humanlayer.
  Leading voice on **context engineering**: "frequent intentional compaction," the
  "Dumb Zone" (40–60% context where recall fails), Research→Plan→Implement. His
  "Writing a good CLAUDE.md" is the most-cited CLAUDE.md guide.
- **Matt Pocock** (`@mattpocock`) — github.com/mattpocock/skills · aihero.dev.
  TS-native AI engineering. **Grill Me** skill (interrogate before coding), Evalite
  (local TS eval runner), Sandcastle (parallel agent sandboxes). "Real engineering,
  not vibe coding" — agents accelerate entropy, so SWE fundamentals matter *more*.
- **Lada Kesseler** (`lexler`) — github.com/lexler · lexler.github.io/augmented-coding-patterns.
  ~60-pattern language for AI coding. **Habit Hooks**, **Knowledge Checkpoints**,
  **user-reminders** hook (re-inject 2–5 critical rules per prompt), **skill-factory**
  (generate skills w/ Anthropic best practices). Make alignment *visible* (emoji markers).
- **Simon Willison** (`@simonw`) — simonwillison.net. Most-read chronicler of
  day-to-day agentic practice; ongoing "Agentic Engineering Patterns."
- **Geoffrey Huntley** — ghuntley.com. Originated the **Ralph Loop** (spec in a file,
  one iteration + commit, restart fresh on full context). Autonomous long-run agents.
- **Anthropic** — github.com/anthropics/skills (official open-standard skills) +
  github.com/anthropics/claude-plugins-official (official plugins — home of the
  **code-simplifier** agent; we now use the built-in `/simplify` instead of vendoring it).

## Canonical collections (index repos)
- `hesreallyhim/awesome-claude-code` — broadest starting index (skills, commands, hooks).
- `obra/superpowers` — installable framework, not a list. Gold-standard skills.
- `anthropics/skills` — official skills (webapp-testing, code-simplifier, skill-creator, mcp-builder).
- `mattpocock/skills` — `npx skills@latest add mattpocock/skills`. Composable, model-agnostic.
- `ComposioHQ/awesome-claude-skills` / `travisvn/awesome-claude-skills` — large curated lists.

## Caveats
- Marketplace install counts and some repo star counts in the wild are vendor/aggregator
  figures — treat as marketing-grade, audit before trusting.
- Marketplaces (claudemarketplaces.com, skillsmp.com) = bigger catalogs, you audit quality/security.
