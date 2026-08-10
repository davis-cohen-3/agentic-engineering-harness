# Mock mode for paid third-party tools

## Context

Today, `approval.mock_mode` (non-prod, default **on**) only short-circuits **approval-gated
sends** and the LinkedIn-visible Unipile ops. Every **paid read** tool — Apollo, Reddit/Apify,
Hunter, PDL, GovCon, Recall, X, web search, BatchData — runs **inline** through
`runExecutorPrepared` and hits the **real** API in *every* environment, burning real credits.
The code even documents the boundary: *"silent reads are never mocked"* ([unipile/client.ts:175](services/api/src/tools/distribution/unipile/client.ts:175)).

This is a real cost leak and a real footgun: a Reddit search "failed" in a demo/PR env purely
because it made a live Apify call, and the failure was invisible (no signal it was a real call).

**Goal:** extend mock mode to cover **all 42 `costClass: 'paid'` tools** in non-prod, returning
**realistic canned data for reads** (so demos/agent flows work) and a **no-op stub for
sheet-population + sends**. Add a **per-provider admin allowlist** so specific vendors can be
flipped back to the real API on demand. Make mocked results **visibly labeled**. Prod is never
mocked.

Decisions locked with the user: **realistic reads + no-op sheets**; **per-provider** override.

## Design summary

- **One seam.** Intercept at `runExecutorPrepared` — [runExecutor.ts:40](services/api/src/tools/runExecutor.ts:40) — the single line `toolDef.executor(ctx, preparedArgs)` that *every* path (chat, tasks, workflows, approvals, scheduler, side-effects) funnels through. The full `ToolDefinition` (`costClass`, `definition.name`, `tags`) is in scope, and returning before the executor runs **automatically skips the credit debits** (they live inside the executors).
- **Gate:** `isMockableEnv && costClass === 'paid' && getConfig('approval.mock_mode', true) && !allowlist.includes(tags[0])`.
- **Provider identity = `tags[0]`** (apollo, apify, hunter, pdl, govcon, recall, x, web, postgrid, batchdata). There is no `provider` field; `getProviderForTool` is a *capability-module* name that does **not** match vendors (`apify`/`recall` mismatch), so do **not** use it here.
- **Reuse the single `approval.mock_mode` master switch** (covers sends + paid reads). The per-provider allowlist is the escape hatch; no second master flag.
- Mocked results carry `mocked: true`, which already reaches the web client verbatim, and render a small **"mocked" badge** on the tool chip.

## Changes

### 1. Interceptor at the executor seam (backend core)

- **New `services/api/src/tools/mockMode/paidToolMock.ts`:**
  - `isMockableEnv()` — `!isProduction && !isTest` (see Risks; add `isTest` to [loadEnv.ts](services/api/src/env/loadEnv.ts) = `envMode === 'test' || !!process.env.VITEST`). This is the critical guard.
  - `shouldMockPaidTool(toolDef): Promise<boolean>` — `isMockableEnv() && toolDef.costClass === 'paid' && await getConfig('approval.mock_mode', true) && !(await getRealApiProviders()).includes(toolDef.tags?.[0] ?? '')`. Wrap `getConfig` in try/catch → on error, **do not mock** (fail open to real behavior, never throw into the executor path).
  - `getRealApiProviders(): Promise<string[]>` — `getConfig<string[]>('approval.mock_mode_real_api_providers', [])`.
  - `buildPaidToolStub(toolDef, preparedArgs): ToolResultOutput` — looks up `PAID_TOOL_STUBS[toolDef.definition.name]`; if present returns its realistic payload, else returns the generic no-op stub. Always sets `mocked: true`.
- **Hook** at the top of `runExecutorPrepared` ([runExecutor.ts:34-40](services/api/src/tools/runExecutor.ts:34)), before the executor call:
  ```ts
  if (await shouldMockPaidTool(toolDef)) {
    log.info('Mock mode: stubbing paid tool', { tool: toolDef.definition.name, provider: toolDef.tags?.[0] });
    return buildPaidToolStub(toolDef, preparedArgs);
  }
  ```
  This composes with the existing upstream approval mock (approval-gated tools are already stubbed before reaching here — no double-mock).

### 2. Paid-tool stub registry — realistic reads + no-op fallback

- **New `services/api/src/tools/mockMode/paidToolStubs.ts`** — `PAID_TOOL_STUBS: Record<string, (args) => ToolResultOutput>`. Each fixture returns data **shaped like the real tool's output** and honors the requested count where relevant (e.g. `redditSearch`'s `limit`, `apolloSearchPeople`'s page size).
  - **Realistic fixtures** for the demo-critical reads: `apolloSearchPeople`, `apolloSearchCompanies`, `apolloEnrichPerson`, `apolloEnrichCompany`, `redditSearch`, `webSearch`, `webExtract`, `hunterFindEmail`, `pdlSearchPerson`, `xSearchTweets`. (Match each tool's real `data` shape — cross-check the tool's success-path `return` and its result rendering in [toolFormatter.ts](apps/smoke-web/src/components/Chat/toolFormatter.ts).)
  - **Generic no-op** (`MOCK_TOOL_RESULT`-shaped, `mocked: true`) for everything else — the `lists/*` **sheet-population** tools (`build`, `append`, `enrichBatch`, `enrichFromProvider`, `searchAndPopulate`, `verifyBatch`, `verifyColumn`), the **sends** (`smokeSendEmail`, `postgrid*`, `xCreateTweet`), and any read without a registered fixture. Message e.g. `"[Mock] Simulated — no external call, no rows written. Add this provider to the mock-mode allowlist in Admin to hit the real API."`
  - Registry is deliberately extensible; the fallback keeps every unlisted paid tool safe (zero spend) by default.
- Model fixtures on the existing frozen singleton shape at [types.ts:409](services/api/src/tools/types.ts:409) but return **fresh objects** (never mutate the singleton).

### 3. Per-provider real-API allowlist (config + admin UI)

- **New migration** `services/api/src/db/migrations/<ts>_seed_mock_mode_real_api_providers.sql` — seed `approval.mock_mode_real_api_providers`, `value '[]'`, `type 'string'` (JSON-array precedent = `model_failover_chain`), with `-- DOWN` deleting the key.
- Add the key to **`NON_PROD_ONLY_KEYS`** ([routes/admin/config.ts:18](services/api/src/routes/admin/config.ts:18)) so it's hidden/blocked in prod like `approval.mock_mode`.
- Add a bespoke validation branch in the `PATCH /:key` handler (model on the CHAIN_KEYS block, [config.ts:71](services/api/src/routes/admin/config.ts:71)): `JSON.parse` → assert `string[]` ⊆ known providers.
- **Shared constant** `MOCKABLE_PAID_PROVIDERS = ['apollo','apify','hunter','pdl','govcon','recall','x','web','postgrid','batchdata']` (+ `lists`, `email` for the orchestrators/sends) — put in a small shared module importable by API + admin.
- **Admin UI** ([apps/smoke-admin/src/pages/Settings.tsx](apps/smoke-admin/src/pages/Settings.tsx)): Settings has **no list control**, so add a dedicated render branch keyed on this config key that renders **one checkbox per provider** from `MOCKABLE_PAID_PROVIDERS`, reading/writing the value as `JSON.stringify(enabledProviders)` (the PATCH validator requires a stringified value, per [config.ts:59](services/api/src/routes/admin/config.ts:59)). Add the key to `HIDDEN_KEYS` so it never falls through to the raw text input. No new WebSocket broadcast needed — the allowlist is consumed only on the backend.

### 4. Visible "mocked" badge (schema + web)

- Add `mocked?: boolean` to `ToolResultOutput` in [packages/schema/src/index.ts](packages/schema/src/index.ts) (~993-1022). Optional → no migration/serialization churn; already flows to the client via SSE + persisted `toolOutput`.
- **Web:** add `isMockedToolResult(output)` helper in [toolFormatter.ts:7](apps/smoke-web/src/components/Chat/toolFormatter.ts) (mirror `isDiscardedToolResult`), thread `mocked` into [ChatMetaRow.tsx](apps/smoke-web/src/components/Chat/ChatMetaRow.tsx) and render a small "mock" badge next to the tool title ([Message.tsx:1128-1258](apps/smoke-web/src/components/Chat/Message.tsx)). The existing `MockModeBanner` continues to signal the global state.

### 5. Tests

- **`paidToolMock.test.ts`:** paid tool + mock on + not allowlisted → returns stub (`mocked: true`), **executor not called, no usage debit**; provider allowlisted → executor called; non-paid (`bundled`/`internal`) → executor called; `isProduction` → never mocked; `isTest` → never mocked (guards the suite).
- **`paidToolStubs.test.ts`:** a few fixtures return correctly-shaped `data` and honor requested count.
- **Regression:** run the **full** API suite — the `isTest` guard must keep every existing `runExecutor`-path test green (this is the main blast-radius check).

## Verification (end-to-end, non-prod dev server)

1. `make check` (lint + build + test) green.
2. `approval.mock_mode` on, allowlist empty: chat *"find 10 recruiters in nyc from apollo"* → **10 realistic fake rows + "mock" badge**; confirm **no Apollo debit** (grep `usage_events` / logs, and the "Mock mode: stubbing paid tool" log line).
3. *"find reddit posts about job searching"* → realistic fake posts + badge, **no real Apify call** (this is the exact flow that regressed).
4. Admin → enable **apollo** in the allowlist → re-run Apollo search → **real** call (badge gone, debit present). Reddit still mocked.
5. A sheet build (`buildAndPopulateData`) → no-op "simulated — no rows" stub, empty sheet, no spend.
6. Set `ENVIRONMENT=production` locally (or unit-assert) → interceptor **never** fires.

## Risks & invariants

- **Test-suite stubbing (highest risk):** `isProduction` is false under vitest, so gate on `!isProduction && !isTest`. Verify by running the whole API suite before/after.
- **Default-on behavior change:** after ship, non-prod envs start stubbing paid reads by default. Intended — but the badge + banner make it visible (the fix for this thread's confusion), and the allowlist is the escape hatch.
- **`getConfig` on a hot path:** it's cached (5s memo → Redis → DB); still, wrap in try/catch and **fail open** (never throw into `runExecutorPrepared`).
- **Module-load DB coupling:** `runExecutor.ts` is a central import. `paidToolMock.ts` pulls in `adminConfig` → `db`; importing it at `runExecutor` module load would drag `DATABASE_URL` into ~17 tool unit tests that don't mock the DB (the known `httpJson`/`adminConfig` coupling). **Defer-import** `adminConfig` (dynamic `import()` inside the async gate) or keep `paidToolMock` free of top-level DB imports.
- **Provider identity:** rely on `tags[0]`; add a lightweight unit assertion that every `costClass:'paid'` tool has a `tags[0]` in `MOCKABLE_PAID_PROVIDERS` so a new paid tool can't silently escape the allowlist.
- **Hotspot:** this is billing/outbound-adjacent — run `reviewer-security` on the diff before shipping.

## Out of scope / follow-ups

- The pre-existing latent Reddit issues (408 double-run retry, jobs-scraper copy in the 408 message) — separate, optional.
- The unipile typeahead route ([routes/integrations/unipile.ts:605](services/api/src/routes/integrations/unipile.ts)) hits real LinkedIn even in mock mode — pre-existing `bundled` gap, not part of this paid-tool layer.
- Full-fidelity synthetic **sheet rows** (option C) — deferred; sheets are no-op stubs in v1.
