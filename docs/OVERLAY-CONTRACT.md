# Overlay contract — what a repo supplies to inherit this harness

`harness-lab` is the **base**: repo-agnostic skills, hooks, agents, and the definition of done.
A repo inherits all of it by filling these **slots** — onboarding fills the slots, it does not
rebuild the harness. The `adopt-harness` skill executes this contract (copy the base, then fill);
this doc is the conceptual reference behind it.

## The slots

| Slot | Repo supplies | Base uses it for | Notes |
|------|---------------|------------------|-------|
| **1. Setup / bootstrap** | install + env provisioning (symlink `.env`, named venv, bring up Postgres/Redis) | makes the gate + run work, esp. in a fresh worktree | Load-bearing for autonomous clones — they fail in a fresh worktree without it. `SETUP_STEPS` in `make/gate.mk`. |
| **2. Quality gate** | a **list of named checks** {build, test, lint, typecheck?, format?, custom[]} | objective "done" + Stop-gate enforcement | NOT one command. Handle ordering deps (build schema first), per-subtarget, partial coverage. Custom architecture linters can't be discovered — the overlay must enumerate them. `GATE_STEPS` in `make/gate.mk`. |
| **3. Launch** | how to run the app (dev server/CLI, ports, modes) | the app is up so it can be exercised | One script with flags, or a multi-service `dev` command. |
| **4. Verify harness** | URL (local/preview), login creds, reporting sink | `verify-before-done` drives a real browser via Playwright/Browserbase MCP | Base = "how to verify" (reproduce→confirm, browser-drive). Overlay = the targets. |
| **5. Conventions** | hierarchical entry doc + index; rules in `.claude/rules/` (`paths:`-scoped or always-on) | shapes how the agent writes code | Mark **enforced** (hooks/linters) vs advisory. `.claude/rules/` holds conventions as their own files — `paths:` scopes a rule to matching files, else it loads always-on like the floor (base ships worked examples; repo fills its own; how-to in `docs/CLAUDE-CODE-RULES.md`). |
| **6. Gate creds** | MINIMAL set to make the gate pass (PG, Redis, JWT, 1 LLM key) | run build/test in CI/worktree | Keep tiny. Conflating with #7 makes a test run demand 30 keys. |
| **7. Runtime creds + MCP** | broad, mostly OPTIONAL provider keys + declared MCP servers | exercise real features / outbound actions | MCP config often lives OUTSIDE the repo (CI). |
| **8. Risk profile** | risky **paths** + risky **operations**, with enforcement | tunes autonomy; where a human must stay | Teeth, not prose: hooks + protected paths. Convergent hotspots: migrations, auth, payments, outbound-send, prod deploy, spend. |

Most slots have base **defaults**; a repo overrides only what differs, and optional slots can be
absent. The fewer a repo must fill, the more ergonomic the harness.

## Distribution
The base must reach autonomous/cloud runs on a fresh clone — the day-one test: a cloud run gets
the repo's `.claude`, never your `~/.claude`. So the base is **vendored** into each repo (via
`adopt-harness`), which is why "what travels" is pinned in one place: the manifest in
`.claude/skills/adopt-harness/copy.sh`.
