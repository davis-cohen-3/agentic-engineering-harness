# Password reset — finalize PRD + write T3 build spec

## Context

Two review rounds verified the "Password Reset — Design and Implementation Scope" doc
(v2, in conversation) against the codebase; all product/security decisions are resolved.
Two flaws remained in the doc text (a rate-ceiling/purge interaction that could silently
defeat the abuse control, and a redaction requirement that already exists in the code),
and Davis asked to fix both and "write the plan." Three Explore agents mapped the spec
conventions and implementation patterns; a Plan agent drafted the epic decomposition and
flagged 7 contradictions/gaps, all resolved below. **This task writes documents only — no
feature code.**

## Deliverables (execution after approval)

1. **`docs/product/password-reset-prd.md`** — the v2 doc with the edit list below applied
   (tracked; sibling of `signup-admission-prd.md`).
2. **`specs/password-reset/`** — T3 epic: `README.md` index + sub-specs `01`–`06`
   (per repo T3 template; DoR-checked; `status: ready`).
3. **Mirror** the epic dir to the main checkout `/Users/daviscohen/smoke/code/smoke-screen/specs/password-reset/`
   (Davis chose worktree + main mirror; specs/ is git-excluded and worktree-recycling has
   destroyed specs before).
4. **`.claude/active-spec`** in this worktree → `specs/password-reset/README.md`
   (no Makefile in worktrees; hand-write the pointer `make work` would create).
5. Invoke the `write-plan` skill for the spec-writing step (marker 📐).

## PRD edit list (exact, nothing else changes)

**Fix 1 — ceiling/purge/invalidate (Token and data model + token requirements).**
Replace the "Do not add a uniqueness rule … maintenance query for older rows." paragraph
with:

> Do not add a uniqueness rule that prevents a new token from being issued while an old
> expired row exists. Issuing a new token must always work subject to rate limits.
>
> Token rows are also the durable rate-limit record, so invalidation and cleanup must not
> erase them early:
>
> - Superseding happens at issue time: issuing a new token marks the user's older
>   outstanding tokens with `superseded_at` (only the newest link can succeed). A
>   successful reset additionally sweeps any remaining outstanding tokens. Invalidation is
>   always by **marking**, never by deleting rows.
> - The per-email ceiling counts rows by `created_at` regardless of token state
>   (outstanding, superseded, used, expired).
> - Retain rows for at least the longest reset rate-limit window (24 hours for v1); purge
>   only rows older than that, opportunistically on issue. A test must assert that
>   issuing, superseding, and consuming tokens does not reduce the count the ceiling sees
>   inside the window.

Add `superseded_at` nullable to the column list; update the "Invalidate prior outstanding
tokens…" bullet to reference marking-not-deletion.

**Fix 2 — redaction (Token requirements + Email requirements).** Replace the "render-only
secret props" sentence with:

> The `email_sends` persistence choke-point already redacts secret template props by
> exact key name (`redactSecretProps` / `SECRET_TEMPLATE_PROP_KEYS` in
> `services/api/src/db/emailSends.ts`). Add `resetUrl`/`reset_url` to that set, and add a
> test asserting the stored `template_props` for both templates contain no token or reset
> URL.

Update the security-mode bullet to "Reuses the existing `SECRET_TEMPLATE_PROP_KEYS`
redaction (exact key-name match) — register the reset-URL prop key there."

**Small corrections (flagged, not silent):**
- Constraints line "There is no frontend Vitest runner" → "There is no component-test
  setup (no RTL/jsdom); pure-logic vitest runs from the root (`test:web-app --root`), so
  extracted page logic is unit-testable; UI states belong in Playwright `e2e/`." (The
  original claim was subtly wrong.)
- Append numeric parameters as decision #10: per-email hourly ceiling **5/hour** (durable,
  from token rows), row retention **24h**, and the rate-limit response split: requester-keyed
  per-IP limits may return 429 (house style, matches login/register); email-keyed limits
  (60s cooldown, DB ceiling) return the generic 200 with no send — a 429 from the DB
  ceiling would itself be an account-existence oracle (only real accounts have token
  rows). Reset-password failed-attempt throttle = per-IP default limiter; no per-account
  counter in v1 (256-bit single-use tokens make guessing moot; documented).

## Epic decomposition (specs/password-reset/)

Order: **01 ∥ 02 → 03 → 04 → 05 → 06** (04/05 disjoint, may parallel; email precedes
routes because routes compile against `EmailService.sendPasswordReset`).

| # | Sub-spec | Scope | Deps | Hotspots |
|---|---|---|---|---|
| 01 | schema-token-service | `password_reset_tokens` + `users.password_changed_at` migration; kill-switch seed migration (`auth.password_reset_mode`, jsonb `"disabled"`); token service (`issue`/`consume`/`supersede`/`countIssuedSince`, import-side-effect-free); admin `DROPDOWN_OPTIONS` custom Disabled/Enabled entry | — | migrations |
| 02 | email-security-mode | `security: true` on `smokeSendEmail` (skip instrumentLinks+pixel+unsub; `isEmailAllowedForUser` keeps 90d bounce/complaint, skips global-unsub+prefs); 2 templates + registry + order-sensitive `listEmailTemplates()` test append; `SmokeEmailType` additions; `buildPasswordResetUrl` in `utils/authLinks.ts`; `SECRET_TEMPLATE_PROP_KEYS` += resetUrl; `EmailService` façade methods | — | outbound-send |
| 03 | auth-routes | `POST /auth/forgot-password` (kill switch → per-IP 429 → email-keyed silent limits → eligibility mirror of `auth.ts:362` → issue+supersede-older → `void` send; byte-identical generic 200 across all email-keyed outcomes) + `POST /auth/reset-password` (≥12 validation; one txn: conditional-UPDATE consume + bcrypt(10) + `password_changed_at=NOW()` + sweep; generic invalid-token response ×5 shapes; no auto-login; marked integration point for 04) | 01, 02 | auth, outbound-send |
| 04 | session-revocation | `RotateResult.createdAt`; normal refresh gate (`auth.ts:1141-1163`) + degraded gate (`:1044-1055`) vs `password_changed_at`; new `pw_iat_cutoff:` Redis key (NOT `evicted_user:`) checked in `verifyToken`; cutoff write after reset commit. Named hazard: iat seconds vs createdAt ms vs timestamptz — dedicated mixed-unit test | 01, 03 | auth |
| 05 | web-ui | Forgot link (password step, `hasPassword`-gated, 14px) + check-your-email panel (waitlist early-return pattern); `/reset-password` page (main.tsx branch, landing-page theme, SignupPage.css --native layout, `useCanonicalUrl`, StrictMode cancelled-guard); targeted `URLSearchParams.delete('token')` strip (never pathname-only wipe); extracted labeled landing password field (label + show/hide + `role="alert"`; migrating existing 3 hand-rolled fields out of scope); pure-logic modules + vitest (`inviteRedirect` precedent); fix `8+ chars` placeholder | 03 | — |
| 06 | e2e-rollout | `POST /auth/test-reset-token` (unauthenticated — pinned divergence from `/approvals/test-seed`; 404 when `isProduction \|\| mode !== 'enabled'`; seeds throwaway `runTag()` user, never shared e2e accounts); journey `password-reset.md` + `.spec.ts` (logged-out storageState, waitForResponse pattern, skip-on-404); integrity script clean; rollout checklist (human flips switch in smoke-admin; rollback = flip back) + observability (email_sends by new types, warn-level queries, metrics) | 03, 04, 05 | auth |

**Epic-level decisions pinned in README:** supersede-at-issue + consume sweep; retention
24h / ceiling 5/hr; 429-vs-200 split (and: do NOT copy `share.ts` 429s for email-keyed
tiers); kill switch stays `disabled` everywhere until 06's rollout step (safety interlock
for the 03-without-04 window); cross-sub-spec API contracts (exact signatures for token
service, façade, route JSON); HTML-only emails; e2e hook seeds its own user.

**Named risks carried into sub-specs:** `listEmailTemplates()` exact-array test (02, rebase
magnet); migration lint (14-digit prefix, `-- DOWN` hard-block, no migrations outside 01);
`main.tsx:91-100` wipes the whole query string when `?auth_token` present → param is
`token`, strip is targeted (05); sibling auth suites' narrow mock factories (existing
rateLimit factory omits `checkRateLimitCustom`) → new imports side-effect-free + full
`npm run test:api` in 03/04; golden-path integrity gate → pre-existing e2e files
byte-identical (06); CORS → link targets `getFrontendUrl()` never the API origin (02).

## Key reuse anchors (for spec context pointers)

- Eligibility/login filter `services/api/src/routes/auth.ts:362`; refresh gates `:1141-1163`,
  `:1044-1055`; fire-and-forget `notifyTeamOfNewSignup` `:65-88`; relay env-gate `:1250-1258`.
- `services/rateLimit.ts:31` (`checkRateLimitCustom`, fails open); two-tier shape
  `share.ts:1005-1016` (keys/tiers only, not the 429s for email-keyed).
- `services/refreshToken.ts:21,32,45` (TokenData.createdAt ms, RotateResult);
  `evictionDenylist.ts` + `middleware/auth.ts:100` (cutoff-check pattern, separate prefix).
- Email: `emails/utils/send.ts:118-128`, `unsubscribe.ts:75-127`, `emailSends.ts:66-76`,
  `templates/welcome-app-access.tsx`, `transactional-invite.tsx:49-59`,
  `render.ts:13` registry, `render-snapshots.test.ts:9-18` order-sensitive list,
  `services/email.ts:25` TRANSACTIONAL_FROM, `utils/authLinks.ts` (+ its `__tests__`),
  `packages/schema/src/index.ts:4` SmokeEmailType.
- Admin: seed pattern `migrations/20260625094920_seed_disable_pre_retrieval_flag.sql`;
  `Settings.tsx:15` DROPDOWN_OPTIONS (custom lists OK); `adminConfig.ts` getConfig
  never-throws/fail-closed, setConfig can't create keys.
- Web: `main.tsx:91-100` hazard + `:118-156` router; `AuthModalForm.tsx:140/258/342/387`;
  `LandingInput.tsx` (no label today); `SignupPage.tsx/.css`; `pages/inviteRedirect.ts(.test)`.
- Tests: `routes/__tests__/authAdmission.test.ts` (server mount, enumeration table
  `:171-194`); `emails/__tests__/*`; `services/__tests__/emailService.test.ts`;
  e2e `login-invalid-password.spec.ts:21-28`, `approvals-inbox.spec.ts:29` skip-on-404,
  `check-golden-integrity.mjs`.

## Verification (for this docs-only task)

- PRD: diff against the pasted v2 shows only the listed edits; both fixes read
  consistently with the account-state table and decisions section.
- Spec: every sub-spec passes the write-plan DoR (7 boxes — no TBDs, objective ACs,
  deps noted, out-of-scope explicit, hotspots flagged, verification stated with npm
  commands since worktrees lack `make check`); epic README pins the decisions +
  contracts above; `status: ready`.
- Files exist in worktree AND main-checkout mirror; `.claude/active-spec` points at the
  epic README.
- Report back with the file list and the DoR checklist result; no commits (Davis ships).
