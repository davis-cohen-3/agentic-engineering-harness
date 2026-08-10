# Resolve `cid:` inline images in the email preview (#2780, rendering half)

```
status: ready          tier: T3 (3 ordered sub-specs; Phase 1 ships standalone)
hotspots: outbound-send (Phase 2), auth (Phase 3)
branch: worktree-cid-inline-images-2780   base: origin/main @ 7ba6ca561
```

## Context

Feature request #2780 ("display inline images in email, copy Gmail exactly") was split; the
open/read-tracking half went to #2348. This is the narrow rendering gap.

The reply/compose/forward approval preview already renders the sender's HTML, and **remote**
images (`<img src="https://…">`) load fine. Images embedded by Content-ID (`<img src="cid:…">`
— logos, newsletter art, essentially every Outlook signature) render as broken boxes, because
nothing ever resolves a cid to bytes. The intended outcome: the approval card shows the quoted
original the way Gmail shows it.

### Reproduction — real inbound message, confirmed

Found in `davis@smoke.ai` (Gmail MCP, read-only):

- thread `19e8882ae3bed63e`, message **`19e8b89ec2753e82`** — Gmail DSN from
  `mailer-daemon@googlemail.com`, 2026-06-03, subject "Delivery Status Notification (Failure)".
- Its HTML body contains, verbatim:
  `<img style="padding:0 24px 16px 0;float:left" width=72 height=72 alt="Error Icon" src="cid:icon.png">`
- The message carries a matching part: `icon.png`, `image/png`, with a live `attachmentId`.

Replying to that thread in the product routes through `buildApprovalPreview` → `buildReplyQuote`
→ the preview's quoted block, so the red error icon renders as a broken box.

> **Owed:** I confirmed the data is real and traced the render path deterministically, but I have
> **not** watched it break in a running browser — plan mode is read-only. Step 0 of the build is
> to drive that repro live and screenshot it, before and after.

## Why it's broken (verified, not assumed)

| Link in the chain | Fact | Where |
|---|---|---|
| Inbound HTML keeps the cid | Nothing rewrites it | `gmail/api.ts:410` `extractBodyContent`; Outlook `msg.body.content` |
| Quote is barely sanitized | Only `stripStyleAndScriptTags`; deliberately bypasses `normalizeEmailHtml` | `email/replyQuote.ts:9-12,48` |
| Gmail Content-ID is *available but never read* | `GmailMessagePart.headers` is typed, `format=full` returns per-part headers, `getHeaderValue` exists — `extractAttachments` reads only filename/mime/size/attachmentId | `gmail/api.ts:19-29,369,443-471` |
| Outlook contentId is *never requested* | `OutlookAttachment` has `isInline`+`contentBytes` but **no `contentId`**, and neither `$expand` sub-select asks for it | `outlook/api.ts:28-35,160,201` |
| Bytes are reachable both ways | Gmail `/messages/{id}/attachments/{attId}` (base64url); Outlook `getAttachment()` **already exists and has zero callers** | `email/downloadAttachment.ts:315`; `outlook/api.ts:412-426` |
| Nothing client-side blocks the fix | dompurify **3.4.0** (pinned, `apps/smoke-web/package.json:57`) default-allows `data:` on `<img src>` (`DEFAULT_DATA_URI_TAGS` includes `img`; attr gate at `purify.cjs.js:1047`). No CSP anywhere blocks `data:` | `EmailPreview.tsx:98,602` |

**Two findings worth carrying into the PR:**

1. The *sent* copy is broken too. `assembleOutboundBody` concatenates the quote verbatim, and the
   Gmail MIME builder only ever emits `multipart/mixed` with `Content-Disposition: attachment` —
   no `multipart/related`, no `Content-ID` anywhere in the repo. So recipients already receive
   dead cid refs today. Phase 1 does not change that; Phase 2 fixes it.
2. The send-time total-size guard (`replyToThread.ts:367`, mirrored in `sendEmail`/`draftEmail`)
   only runs `if (attachmentRows.length > 0 || ephemeralSizes.length > 0)`. A reply with a huge
   quote and no attachments is **never size-checked**. Phase 2 must make it unconditional or
   re-attached inline bytes bypass it.

## Resolved decisions

| # | Decision | Why |
|---|---|---|
| 1 | **Inline as size-capped `data:` URIs at build time.** | No new auth surface; works identically in dev and prod; immune to Gmail's rotating `attachmentId` (resolved inside the same fetch); prior art in `sitePreview.ts:294` `fetchInlineImage`. Rejected **proxy route**: `<img src>` can't carry a Bearer header (`verifyToken` reads `req.headers.authorization` only, `middleware/auth.ts:71`), so it would need a URL-embedded token — new auth surface for the common path. Rejected **publicAssetStorage rehost**: `S3PublicAssetStore` writes `ACL: 'public-read'`, no TTL — that publishes a customer's private inbound email imagery to the open internet. Wrong trade for this content class. |
| 2 | **Preview-quote build only.** Not `getMessage`/`getThread`. | Those feed the *model*, not the eye. Base64 in tool results would be a direct token-cost hit and the model can't see images in tool results anyway (they're text-only). |
| 3 | **Phase 1 preview-only; Phase 2 delivers true parity by re-attaching as `multipart/related`.** Never `data:` in the sent copy. | Gmail and Outlook both strip/refuse `data:` image srcs in received mail — the recipient would still see nothing while the message grows ~33% per image and spam scoring worsens. Real parity is the MIME fix, and it's tractable (see Phase 2). |
| 4 | **Guards** (below) — reference-driven fetch, magic-byte sniff, hard caps, fail-open. | |
| 5 | **Gmail: read part headers. Outlook: add `contentId` to the sub-select, use the existing dead `getAttachment()`.** | Structure is already on the wire for Gmail; Outlook needs one field and gains a caller for dead code. |

**Trap to respect:** `footerImages.ts:29` `UNRENDERABLE_PROTOCOLS = {'cid:','data:'}` strips **both**
from *footers*. The quote is a different surface and must not be routed through it. Its existing
tests must stay green untouched.

## Design

New module `services/api/src/tools/pipedream/email/inlineCidImages.ts`:

```ts
interface InlineImagePart { cid: string; mimeType: string; size: number; fetchBytes(): Promise<Buffer|null> }
interface CidResult { html: string; resolved: number; unresolved: UnresolvedInlineImage[] }
async function inlineCidImages(html: string, parts: InlineImagePart[], opts): Promise<CidResult>
```

- **Short-circuit**: `if (!/src\s*=\s*["']?cid:/i.test(html)) return { html, ... }` — zero cost on
  the overwhelmingly common path.
- **Reference-driven**: parse once, collect referenced cid tokens (RFC 2392 — URL-decode, strip
  `<>` from the part's `Content-ID`, case-insensitive fallback, `X-Attachment-Id` as secondary
  key). Fetch **only** parts a `src="cid:…"` actually names — never every attachment.
- **Parse, don't regex.** Reuse the parse5 helpers `stripStyleAndScriptTags` uses
  (`normalizeHtml.ts:590`).
- **Magic-byte sniff** — reuse `detectMimeType` (`services/avatarCache.ts:23`); the stored bytes
  decide the type, not the declared header. Allowlist PNG/JPEG/GIF/WEBP; drop SVG (unsniffable,
  not worth the surface for cross-user-visible content).
- **Caps**: `MAX_INLINE_IMAGE_BYTES = 100 KB`, `MAX_INLINE_TOTAL_BYTES = 400 KB`,
  `MAX_INLINE_IMAGES = 10`, concurrency 4, ~5s overall budget. Signature logos are 2–30 KB, so
  these are generous; the caps exist because the preview persists to `pending_approvals.preview`
  JSONB **and** streams over SSE, neither of which has any size guard today.
- **Fail-open**: any failure leaves the `cid:` untouched and logs a warn. Never blocks the preview.

Provider adapters: `gmail/inlineParts.ts` (walk the part tree for `Content-ID` /
`Content-Disposition: inline` + `body.attachmentId`; lazy fetch + base64url-decode via
`gmail/encoding.ts:3`) and `outlook/inlineParts.ts` (lazy fetch via existing `getAttachment()`).

**Seam — one call site.** All four preview writes to `replyQuoteHtml` (`agentLoop.ts:6138`,
`:6213`, `:6298`, `:6304`) converge at `agentLoop.ts:6331` `buildEmailPreview`. Track a
`quoteSource { provider, messageId, parts }` alongside `replyQuoteHtml` and `await inlineCidImages`
once, immediately before that call — covers reply + forward × Gmail + Outlook.

Gmail already has parts+headers in hand (`getThread(userId, threadId, 'full')`); no extra
structural fetch. Outlook's preview fetch (`agentLoop.ts:6135`) needs
`attachmentsMetadataOnly: true` with `contentId` added to the sub-select at `outlook/api.ts:160,201`
— metadata only, so the "tens of MB" payload concern documented at `outlook/api.ts:118-125` stays
respected; bytes come per-image from `getAttachment()`.

**No frontend change in Phase 1.**

## Task decomposition

**Phase 1 — preview renders inline images** (no hotspot; ships standalone)
1. Drive the live repro (thread `19e8882ae3bed63e`) and screenshot the broken box — deps: none
2. `inlineCidImages.ts` + unit tests — deps: none
3. Gmail inline-part extraction (`gmail/inlineParts.ts`) — deps: #2
4. Outlook: `contentId` on the type + both sub-selects; `outlook/inlineParts.ts` — deps: #2
5. Wire the single seam at `agentLoop.ts:6331` — deps: #3, #4
6. Re-drive the repro; screenshot the icon rendering — deps: #5

**Phase 2 — true Gmail parity on send** (⚠️ outbound-send → `reviewer-security`)
7. `buildGmailRawMessage`: nest `multipart/related` (HTML part + `Content-ID`/inline image parts)
   inside `multipart/mixed`; `multipart/related` as top level when there are no file attachments
8. Outlook: `contentId?`/`isInline?` on `GraphFileAttachment` + an inline builder variant
9. **Make the send-time total-size guard unconditional** (`replyToThread.ts:367` + the
   `sendEmail`/`draftEmail` mirrors); budget against Outlook's ~2.25MB ceiling and degrade
   (re-attach what fits, leave the rest as today) rather than failing the send
10. Resolution runs again at send time from a fresh fetch (the preview's bytes are deliberately
    not reused — the quote is already rebuilt independently at send; see "same string?" below)

**Phase 3 — "view as a file" for unresolved images** (⚠️ auth → `reviewer-security`)
11. Carry `unresolvedInlineImages[{ cid, filename?, mimeType?, size?, messageId, provider }]` on
    the preview payload
12. New authenticated `GET` endpoint that re-resolves by Content-ID against a fresh `format=full`
    fetch (this is what absorbs Gmail's attachmentId rotation) with workspace-membership authz
13. Chip row **below the quote** — deliberately *not* the attachment strip, whose entries
    (`attachedImages`, `forwardedAttachments`) mean "will be sent"; click → `authFetch` → blob →
    open, mirroring `fetchAttachmentObjectUrl` (`services/attachments.ts:409`)

## Acceptance criteria

- [ ] #2: cid matching handles `<>`-wrapped Content-ID, URL-encoded tokens, case mismatch,
      `X-Attachment-Id` fallback; caps enforced per-image/total/count; non-image bytes rejected by
      sniff; missing part → unresolved, not thrown; fetch error → original `cid:` preserved;
      no-cid HTML returns byte-identical input
- [ ] #5: replying to thread `19e8882ae3bed63e` yields a preview whose quote contains
      `<img src="data:image/png;base64,…">` and no `cid:`
- [ ] #6: the red error icon is visible in the approval card (screenshot)
- [ ] Existing `footerImages` / `updateFooter` / `normalizeHtml` tests unchanged and green
- [ ] Phase 2: a Gmail reply quoting an inline image arrives at a real external mailbox with the
      image rendered inline; Outlook likewise; an over-budget Outlook case degrades instead of 4xx
- [ ] Phase 2: the total-size guard fires on a quote-only (zero-attachment) oversized reply
- [ ] Phase 3: an over-cap inline image appears as a chip below the quote, opens on click, and
      does **not** join the outgoing attachment set

## Out of scope

- Remote-image proxying / "display images below" gating (separate)
- Open/read tracking → #2348
- A standalone email reader
- Inline images in the **agent-authored body** — TipTap has no Image extension, so `<img>` is
  dropped on hydration and destructively re-saved (`EmailBodyEditor.tsx:173-178`). Different bug,
  different fix.
- Gmail's inline-vs-attachment asymmetry (Outlook filters `!isInline` at 4 sites, Gmail doesn't,
  so Gmail inline images leak into every attachment list). Pre-existing; note it, don't fix it here.

## Verification

- Gate: `npm run lint`, `npm run build`, `npm run test` (this worktree has no `Makefile` — the
  harness gate is main-checkout-only; build `@smokescreen/schema` first)
- Manual (the load-bearing one): reply to thread `19e8882ae3bed63e` in the running app; the DSN's
  `cid:icon.png` renders. Before/after screenshots.
- Phase 2: send to a real external Gmail **and** Outlook mailbox and inspect received source for
  `multipart/related` + `Content-ID`.

## Context pointers

- `services/api/src/tools/pipedream/email/replyQuote.ts` — quote builder (pure, sync; leave it that way)
- `services/api/src/chat/agentLoop.ts:6074-6337` — the four preview writes and the single seam at `:6331`
- `services/api/src/tools/pipedream/gmail/api.ts:19,369,410,443` — part headers, `getHeaderValue`, extractors
- `services/api/src/tools/pipedream/outlook/api.ts:28,160,201,412` — type, both sub-selects, the dead `getAttachment()`
- `services/api/src/tools/pipedream/email/downloadAttachment.ts:314-322` — byte-fetch + base64url pattern
- `services/api/src/utils/sitePreview.ts:294` / `services/api/src/services/avatarCache.ts:23` — data-URI + magic-sniff prior art
- `services/api/src/tools/pipedream/gmail/mimeAttachments.ts` — Phase 2's single MIME builder
- `apps/smoke-web/src/components/TaskApproval/EmailPreview.tsx:98,602` — sanitize + quote render (no Phase 1 change)

## Note for review: preview and sent quote are *separate strings*

`buildReplyQuote` runs twice — once in `agentLoop` for the card, once in
`replyToThread`/`sendEmail`/`draftEmail` from a fresh provider fetch. `preview.replyQuoteHtml` is
documented write-once/display-only and is never read at send. That's why Phase 1 can change the
preview without touching the wire, and why Phase 2 needs its own resolution pass.
