# Recommended MCP servers — agentic-app harness

Brief catalog of MCP servers worth wiring into a repo's `.mcp.json`. The **base ships
`.mcp.json` empty** (`{"mcpServers": {}}`) — every server loads tool schemas into context on
launch, a token tax not every repo should pay, so servers are added per-repo from this catalog.
Markers: `[ADD]` = recommended · `[SKIP — prefer CLI]` = capable MCP this harness intentionally
skips in favor of a CLI. Discovery & cred plumbing at the bottom.

## Starter set (5 — don't over-install)
Each MCP loads its full tool schemas into context; CC degrades well before ~40 tools.
**Install 4–6, prefer servers with toolset/feature filtering, enable only what a task needs.**

- **`[SKIP — prefer CLI]` github** — issues, PRs, code search, Actions, Projects. The MCP is
  high-impact, BUT this harness deliberately uses the **`gh` CLI** instead (lower token tax, no
  always-on tool schemas, and the build skills already lean on it). Reach for the MCP only if you
  need its structured Projects/Actions tools. Creds: OAuth 2.1+PKCE or scoped PAT. `github/github-mcp-server`.
- **`[SKIP — prefer CLI]` postgres-readonly** — DB inspection. Same call as github: prefer the
  **`psql` CLI** over a traveling server. If you do want it, prod-grade pick is **Postgres MCP Pro**
  (`crystaldba/postgres-mcp`, Restricted Mode) since Anthropic's reference server is archived; or
  **Supabase MCP** if Supabase-backed (OAuth; `read_only=true` + `project_ref=<id>`).
- **`[ADD]` datadog** — metrics, logs, traces, monitors, incidents. Official server is **remote
  HTTP + OAuth** (run `/ddsetup`; no keys in config — credentials stay local, never reach the
  model). Drop this into a repo's `.mcp.json` when it actually ships to prod:
  ```json
  { "mcpServers": { "datadog": {
      "type": "http",
      "url": "https://mcp.datadoghq.com/api/unstable/mcp-server/mcp"
  } } }
  ```
  EU/US3 swap the domain (`mcp.datadoghq.eu`, `mcp.us3.datadoghq.com`); append `?toolsets=all`
  to widen scope. Headless/CI fallback is API-key headers (`DD_API_KEY`/`DD_APPLICATION_KEY`).
  `datadog-labs/mcp-server`.
- **`[ADD]` playwright** — drives the browser via accessibility tree (not screenshots →
  deterministic, no vision model). Core for the job-search agent (form/application flows)
  + E2E for the SMB UI. `claude mcp add playwright -- npx @playwright/mcp@latest`. No creds.
  ⚠️ Cost footgun: MCP browser tasks are token-heavy (~114k vs ~27k via the Playwright CLI);
  Playwright team recommends the **CLI for coding agents**, MCP for chat UIs. Benchmark your flows.
- **`[ADD]` context7** — injects up-to-date, version-specific library docs into context
  ("use context7"). Counters stale-training-data hallucination on fast-moving TS/AI SDKs.
  `npx -y @upstash/context7-mcp --api-key ...`. Creds: optional key (raises rate limits).
- **`[ADD]` linear** — find/create/update issues; returns a `branchName` per issue CC uses
  to auto-checkout. Remote, OAuth 2.1. `https://mcp.linear.app/mcp`.

## Add when in production
- **`[ADD]` sentry** — pull/analyze issues, traces, perf. Ships as a CC plugin that
  delegates to a `sentry-mcp` subagent. OAuth, no keys to store. `https://mcp.sentry.dev/mcp`.

## For the agent's cognition (build phase of your apps)
Mental model: GitHub/Linear/Sentry/DB = the agent's *senses & hands*; below = its *cognition*.
- **`[ADD]` memory** — knowledge-graph persistent memory across sessions. Relevant to both
  apps AND a readable reference impl for the memory pattern you'll build. `modelcontextprotocol/servers`.
- **`[ADD]` sequential-thinking** — structured multi-step reasoning/reflection; better
  planning on multi-stage agentic flows. `modelcontextprotocol/servers`.
- **`[ADD]` fetch + exa/brave** — web grounding. fetch (URL→markdown, no creds) for parsing;
  Exa (semantic/research) + Brave (specific lookups) for the job-search agent's research.

## Cred plumbing & security (footguns)
- **Secrets in `.mcp.json`:** use `${VAR}` / `${VAR:-default}` expansion — keep keys in shell
  env / `.env`, reference by name so the file commits safely (this harness already does this).
  Gap: no native `envFile` loader yet (CC issue #28942) — env must be set before expansion.
- **Prefer OAuth remote servers** (GitHub, Supabase, Sentry, Linear) over static tokens — nothing to store.
- **Scope deliberately:** read-only/restricted modes for prod (Supabase `read_only`, Postgres
  Restricted Mode); least-privilege OAuth grants. The spec's own guidance: progressive scope elevation.
- **Prompt injection / tool poisoning is real:** tool output + descriptions enter context; a
  malicious server can hide instructions there (documented: postmark-mcp BCC'd every email).
  Mitigations: allowlist vetted servers only · human-in-the-loop on write/destructive tools ·
  prefer structured/schema'd output · local stdio servers run with YOUR full privileges — review
  `command`/`args` before approving.

## Where to discover more
- Official registry: registry.modelcontextprotocol.io · reference servers:
  `modelcontextprotocol/servers` (filesystem, git, fetch, memory, sequential-thinking, time).
- Lists: `punkpeye/awesome-mcp-servers` (mcpservers.org). Directories: PulseMCP (hand-reviewed,
  shows real usage), Glama (largest, auto-indexed), Smithery (hosted remote servers).
