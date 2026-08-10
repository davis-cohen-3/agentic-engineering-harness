# Issue #2780 — Gmail-parity inline image rendering in the email approval preview

**Tier:** T2 (standard feature) · **Mode:** scope + plan only, no implementation
**Landing spot for this doc on approval:** `specs/issue-2780-inline-images.md` (`specs/` is git-ignored via `.git/info/exclude:61`, consistent with prior specs)

---

## Context

CEO feature request #2780: *"display images in email, copy Google's [image] behavior exactly."*
Two strands are split out and **not** in this task: open/read pixel tracking (→ #2348) and a
standalone inbox/reader surface (explicitly not wanted).

The surface in scope is the one Smoke already shows received email in: the reply/compose/forward
**approval preview** (`apps/smoke-web/src/components/TaskApproval/EmailPreview.tsx`). No new UI surface.

Gmail's image behavior has three separable dimensions. Only one is actually broken:

| # | Dimension | State today |
|---|---|---|
| 1 | **Inline `cid:` images** (embedded logos, most Outlook signatures) | **Broken** — renders a grey box |
| 2 | Remote `https:` images | Render, but loaded direct from the sender's server (no proxy, no caching) |
| 3 | "Display images below" gate | **Absent** — remote images auto-load unconditionally |

**Outcome:** an Outlook signature, a newsletter logo, or a pasted screenshot in a quoted message
renders in the approval preview instead of a broken-image box.

---

## Reproduction (ran, not assumed)

Drove the real code path with an Outlook-signature-shaped message via `npx tsx`:

```
=== replyQuoteHtml that reaches the preview ===
...<blockquote class="gmail_quote" ...><p>Thanks, talk soon.</p>
<div><table><tbody><tr><td><img width="120" height="40" style="width:1.25in;height:.4166in"
  id="Picture_x0020_1" src="cid:image001.png@01DA5F2E.9B4C1A70"></td>
<td><b>Rado Kotorov</b><br>CEO<br><img src="cid:image002.png@01DA5F2E.9B4C1A70" ...> smoke.ai</td>
</tr></tbody></table></div></blockquote>

cid: refs surviving into the preview payload: [ 'image001.png@01DA5F2E.9B4C1A70',
                                                'image002.png@01DA5F2E.9B4C1A70' ]

=== extractAttachments() output for those same parts ===
[ { "filename": "image001.png", "mimeType": "image/png", "size": 8123,
    "gmailAttachmentId": "ANGjdJ_ROTATES_EVERY_READ" }, ... ]
```

**The gap, precisely:** the `cid:` refs arrive at the browser intact, and `extractAttachments`
(`services/api/src/tools/pipedream/gmail/api.ts:443-471`) sees the very same parts — but drops
`part.headers`, which is the only place `Content-ID` lives. There is **no Content-ID → bytes
mapping anywhere in the repo**. The browser cannot resolve `cid:`, so it paints a broken image.

Also verified against the shipped `dompurify@3.4.8` bundle: `cid` is in the default
`IS_ALLOWED_URI` allowlist, and `img` is in `DEFAULT_DATA_URI_TAGS` — so **no DOMPurify config
change is needed** (Decision F). `blob:` is *not* allowed, which constrains the frontend design below.

---

## Current state — verified facts the plan rests on

- **Quote build is unfiltered by design.** `buildReplyQuote` (`email/replyQuote.ts:40-54`) runs only
  `stripStyleAndScriptTags`, which removes whole `style/script/noscript/head/title/link/meta`
  elements (`email/normalizeHtml.ts:580`). No tag, attribute, or protocol filtering. `<img>` passes verbatim.
- **The preview path already has the full part tree, free.** `getThread(userId, threadId, 'full')`
  at `chat/agentLoop.ts:6197`; `GmailMessagePart.headers` is typed (`gmail/api.ts:19-28`) and
  populated at `format=full`. Nothing reads it.
- **Gmail `attachmentId` rotates between reads** (`gmail/index.ts:122`, `email/forwardAttachments.ts:19-24`).
  It can never be persisted and re-used later.
- **Outlook preview path requests no attachments at all** — `$select` with no `$expand`
  (`agentLoop.ts:6133`, `:6301`). `OutlookAttachment` (`outlook/api.ts:28`) has `isInline` but **not**
  `contentId`. A `getAttachment()` already exists (`outlook/api.ts:413`); Outlook ids *are* stable.
- **The sent copy is rebuilt independently.** The outbound quote comes from a *fresh* provider fetch at
  send time (`email/replyToThread.ts:292`/`:532`, `email/sendEmail.ts:209`/`:499`), **not** from the
  preview. A preview-only change is therefore send-path-neutral by construction.
- **`pipedreamProxyRequest` has no timeout and no AbortSignal** (`services/pipedream.ts:335-405`;
  only Pipedream-SDK `maxRetries`). `mapWithConcurrency` (`utils/asyncPool.ts:8-27`) has no abort.
  A hung provider call hangs its caller indefinitely.

### Why bytes must not go into the persisted preview

The obvious MVP — inline `cid:` as size-capped `data:` URIs at preview-build time — was tested and
**rejected**. `preview` is a `jsonb` column that is *searched and filtered as text*:

- `pendingApprovalManager.ts:696-701` — keyword search is `preview::text ILIKE '%kw%'`. Base64 is
  ~⅔ letters over a 64-char alphabet and `ILIKE` folds case, so a 4-letter keyword against just a
  30KB signature has a ~2.8% spurious-hit rate **per approval** — ~76% chance of at least one wrong
  match on a 50-row workspace. That is a silent correctness regression (agent denies/edits the wrong
  approval), and it is not fixable by tuning caps.
- `pendingApprovalManager.ts:774-777` — `countFiltered` filters on `preview->>'type'`, which forces
  Postgres to fully decompress every TOASTed row on every Outbox badge query. `listFiltered` uses
  `SELECT *` with `LIMIT 50`.
- `tools/approval/index.ts:351,385` — `getApproval` truncates fields at 6000 chars; a single hero
  image would consume the agent's whole view of the quote.
- It adds provider round-trips to the **approval-creation critical path**, where the proxy has no timeout.

Two cost claims in the original framing did **not** survive checking, and are corrected here: the
full-preview compare-and-set (`pendingApprovalManager.ts:474-479`) is `persistRecipientCache`, a
LinkedIn-only path (sole caller `:451`) — the email edit path `updateApprovalEdits` (`:1150`) is a
plain `WHERE id = $1`. And the client never PATCHes the preview back up, so `express.json({limit:'10mb'})`
is not in play.

The read-time-injection seam (`footerHtml`/`provider`, `routes/approvals.ts:376-386`) was also
rejected: `fetchSingleApprovalExtras` is called on the **autosave PATCH response**
(`routes/approvals.ts:2313`, confirmed inside the `updateApprovalEdits` branch), so hanging
resolution there means provider round-trips every 250ms of typing.

---

## Decisions

| | Decision | Resolution |
|---|---|---|
| **A** | Phasing / MVP boundary | **Phase 1 = Dimension 1 (`cid:`) only.** Confirmed with Davis. Dimensions 2–3 are Phase 2/3 (see Roadmap). |
| **B** | cid resolution strategy | **Lazy, authenticated per-image route + frontend blob swap.** Not `data:` in the preview (see above), not HMAC-signed public URLs (a leaked URL hands out private mail bytes; `verifyOpenSig` is prior art for a *tracking pixel*, not for attachment bytes), not `publicAssetStorage` (world-readable and unsigned by design — `publicAssetStorage.ts:8-17`). Rotation-immune: the route does `messages.get` + `attachments.get` inside one request. |
| **C** | Where resolution happens | **Preview surface only.** Explicitly *not* `getMessage`/`getThread` — those feed the model, and base64 in tool results is a direct token/cost hit. `preview.replyQuoteHtml` keeps `cid:` verbatim; resolution is a render-time concern. |
| **D** | Send-path behavior | **Leave alone; track separately.** Confirmed with Davis. Preview-only is send-neutral by construction. Sent replies *do* ship broken `cid:` to recipients today — a real pre-existing bug (Gmail's `mimeAttachments.ts` builds `multipart/mixed` only, never sets `Content-ID`; Outlook's `GraphFileAttachment` has neither `isInline` nor `contentId`). File it; do not bundle a recipient-visible change into a preview PR. |
| **E** | Remote-image proxy + gate trust model | Deferred to Phase 2/3. Recommendation when it comes up: gate first (always-ask, no memory — Gmail's own default for unknown senders), proxy second. |
| **F** | Guards | See "Guards" below. DOMPurify needs **no** change — verified in the shipped bundle. |

---

## Phase 1 plan — decomposed

Ordered; each task independently testable. Tasks 1–3 are pure/unit-testable → TDD.

### T1 — Content-ID resolver (pure, server) · `email/inlineImages.ts` (new)
Two halves, both pure:

**(a) cid-reference extraction from quote HTML.** Do **not** regex for `src="cid:"`. Use
`parseFragment`/`stringifyTree` from `normalizeHtml`, the way `email/footerImages.ts:17` already does.
Must cover, in real-world frequency order: `src`, `background` on `<td>` (pervasive in signature
tables), `srcSet` (note hast camelCase — `footerImages.ts:114`; the repo already has a test at
`__tests__/footerImages.test.ts:130`), and `style="background-image:url(cid:…)"` (survives both
`stripStyleAndScriptTags`, which removes `<style>` *elements* not style *attributes*, and DOMPurify,
which does not filter CSS `url()` protocols). Reuse `decodeHtmlEntities` (`footerImages.ts:32-51`)
for entity-encoded attribute values.

**(b) Three-tier part matching.** One tier is not enough:
1. `Content-ID` — strip `<>` (the header is `<abc@def>`, the URL body is bare per RFC 2392);
   percent-decode inside a try (`decodeURIComponent` throws on a lone `%`); exact, then case-insensitive.
2. `X-Attachment-Id` — Gmail-composed messages carry both; some carry only this.
3. Part `filename` — Apple Mail and many clients emit `cid:image001.png` with **no** Content-ID;
   Outlook/Graph returns `contentId` *without* brackets and frequently `null`, referencing the
   attachment `name`.

Tiers 2–3 are the difference between "works on Gmail-composed threads" and "works".

### T2 — Gmail part walker + shared byte fetch · `gmail/api.ts`
- `extractInlineImageParts(payload)` — recursive walk reading `part.headers`. **Must not** reuse
  `extractAttachments`' gate (`payload.filename && body.attachmentId`, `:455`): inline parts are
  indistinguishable from real attachments there, and some inline parts have no filename at all.
- Promote a shared `getAttachment(userId, messageId, attachmentId)`, deduping the two hand-rolled
  copies at `email/downloadAttachment.ts:315` and `email/forwardAttachments.ts:105`.
- **Verify during build** (unconfirmed): whether Gmail populates `part.body.data` inline for small
  parts at `format=full`. If it does, decode locally and skip the network entirely for 1–2KB icons.

### T3 — Outlook parity · `outlook/api.ts`
Add `contentId` to `OutlookAttachment` (`:28-35`) and to the metadata `$select` at `:160` and `:201`.
Reuse the existing `getAttachment` (`:413`). Do **not** switch the preview path to
`$expand=attachments` (full bytes) — that pulls every non-inline attachment too.

### T4 — Authenticated image route · `routes/approvals.ts`
`GET /api/approvals/:id/inline-image?cid=…`, behind the existing `verifyToken`.

- **Authorization is the hotspot.** Verify the requesting user owns the approval. Critically, `cid`
  must be resolved **only against that approval's own message part tree** — never treated as a
  free-form pointer to an arbitrary attachment id. This is the IDOR surface; get it wrong and the
  route reads any message in the mailbox.
- Re-derive `threadId` + anchor from the approval's `tool_input`/`edited_input`, reusing
  `requireAnchorMessage` (`agentLoop.ts:6204-6205`) so the route resolves the same message the
  preview quoted.
- Stream bytes with the part's `Content-Type` and `Cache-Control: private`.
- Short in-process LRU `messageId → (cid → part)` (30–60s) so 4 signature icons cost
  1 `messages.get` + 4 `attachments.get`, not 4 + 4.

### T5 — Frontend swap · `EmailPreview.tsx`
`sanitizeWithOpenInNewTab` (`:98-108`) is **not** a usable seam — its `container` at `:101` is a
throwaway that gets stringified back out at `:107` into `dangerouslySetInnerHTML`. The swap point is
a **post-mount `useEffect` on a ref to the rendered quote div** (`:596-604`):

1. Query `img[src^="cid:"]` on the live node.
2. Authed `fetch()` (Bearer — the app has no cookie auth, `middleware/auth.ts:71-83`) → `URL.createObjectURL`.
3. Assign `img.src = objectUrl` **on the live node**. This never re-enters DOMPurify, so `blob:`
   being outside its default allowlist is a non-issue — but it does mean the result must never be
   re-serialized and re-sanitized.
4. Push to the existing `createdObjectUrlsRef` so the unmount effect at `:404-409` revokes them.
5. Re-run when `quotedHtml` changes (the `quotedContent` memo at `:583` rebuilds innerHTML).

Degradation: on failure, **drop the `<img>`** rather than leaving a grey box — `footerImages.ts:104-118`
(`dropImages`) already implements exactly this, including the "does `srcset` still back this image?"
check. A half-resolved signature (logo renders, two icons grey) reads as a bug more than an
all-broken one does; prefer all-or-nothing per message.

### T6 — Tests
- Unit (T1): cid extraction across `src`/`srcSet`/`background`/CSS `url()`/entity-encoded; all three
  matching tiers; bracket-strip + percent-decode; the lone-`%` throw case.
- Unit (T2/T3): part walker over a `multipart/related` fixture incl. a filename-less inline part.
- Route (T4): **authz negative tests are the priority** — another user's approval id; a `cid` not
  referenced by that approval's quote; a non-image mime; an oversize part.
- Frontend (T5): cid img → blob swap, revoke-on-unmount, failure drops the img.
- There is currently **no** test asserting an assembled outbound body, and **no** `cid:` case in
  `__tests__/replyQuote.test.ts`. Add a `cid:`-passes-through-verbatim case there to pin Decision D.

### Guards (Decision F)
- Resolve only cids **actually referenced** by the quote — never every attachment.
- Mime allowlist `image/(png|jpeg|gif|webp)`. **Exclude `image/svg+xml`.** `sitePreview.ts:311-315`
  permits SVG, but its own comment justifies that by "never persisted or surfaced cross-user" —
  which is exactly false here (the preview is persisted, and admin views it cross-user via
  `apps/smoke-admin/src/components/ApprovalPreviewModal.tsx:36`).
- **Enforce size caps pre-fetch**, from `part.body.size` (`gmail/api.ts:23`) / Graph `size` — not
  after transferring 5MB. Suggested: 2MB/image, 8 images per message.
- Bounded parallelism via `mapWithConcurrency` (`utils/asyncPool.ts:8`) — this path would be its
  first consumer among the attachment resolvers (both existing ones are serial `for…of`).
- **Per-request deadline (~5s) with real cancellation.** `pipedreamProxyRequest` will not time out
  for you. On the lazy route a hang costs one image, not approval creation — but it still needs a bound.
- DOMPurify: no change. Verified.

---

## Out of scope / accepted

- Open-read pixel tracking (#2348); any standalone reader or inbox surface.
- **`ApprovalPreviewCard`** (`packages/components/src/approvalPreviews/`, rendered by smoke-admin)
  keeps showing broken `cid:` — it renders `preview.replyQuoteHtml` through a bare
  `DOMPurify.sanitize` with no route access. Accepted: internal surface.
- The `message/rfc822` sub-part hazard — `extractBodyContent`'s pre-order DFS (`gmail/api.ts:425-433`)
  could pick an attached `.eml`'s `text/html` before the top-level one. Rare, and it fails closed
  (unmatched cid → dropped img). Documented, not fixed.

## Roadmap beyond Phase 1
- **Phase 2 — "Display images below" gate (Dimension 3).** Closes a live leak: remote images are
  fetched when `container.innerHTML = sanitized` runs at `EmailPreview.tsx:102`, i.e. at *sanitize*
  time, before render and regardless of whether the user opens the card. Must rewrite srcs
  **server-side** or before that line — a render-time gate is too late.
- **Phase 3 — remote-image proxy (Dimension 2).** Caching + IP hiding. Largest lift, smallest
  marginal payoff once the gate exists.
- **Separate — send-path parity (Decision D).** `multipart/related` + `Content-ID` on Gmail, `isInline`
  + `contentId` on Graph.

---

## Definition of Ready — met
Design resolved (A–F), no open design questions, tasks ordered and independently testable, every
claim traced to `file:line`, repro run and captured. Ready for a build run.

## Definition of Done
1. `npm run lint && npm run build && npm run test` green (this worktree has no `Makefile` — the
   harness gate is local-only; `build:schema` before `build:web-app`).
2. **Ran it and watched it work**: a real received email with an Outlook signature renders its logo
   in the approval preview, in the running app. Compiling is not working.
3. `reviewer-security` engaged — this is a hotspot (data exposure: a route serving mailbox
   attachment bytes; IDOR is the named risk in T4).
4. Own-diff review against this plan.

## Verification
- **Repro-then-fix:** re-run the `tsx` harness above; `cid:` must still pass through
  `buildReplyQuote` verbatim (the preview payload is deliberately unchanged) — the fix is at render.
- **Live, authed UI drive:** send an Outlook-signature email into a connected mailbox, have the agent
  draft a reply, open the approval card, confirm the logo renders and the network tab shows the
  authed route (not a direct fetch to a sender host).
- **Authz probe:** call the route with another user's approval id and with a `cid` not present in
  the quote; both must 403/404.
- **No-regression:** approval-creation latency unchanged (nothing added to that path); Outbox list
  and keyword search unaffected (preview blob size unchanged).

## Pre-flight
Branch `claude/scope-issue-2780-ba5201` is **3 commits behind `origin/main`** — rebase before
building (`git rebase origin/main`; `git reset --hard` is hook-blocked). `node_modules` and both
`.env` files are present and populated in this worktree.
