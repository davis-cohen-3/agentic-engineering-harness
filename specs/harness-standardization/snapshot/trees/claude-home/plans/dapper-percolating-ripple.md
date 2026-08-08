# user_profiles schema — resolve R-002/R-003 into DECs

## Context

A schema review after the compensation CHECK fix (PR #49, migration 018) produced three register
entries in `agent_docs/revisit.md`. Two were flagged as needing design calls. This session resolved
them — and found that the premise was off in a way that matters.

**The decisions already existed.** The spec repo has an unpushed local branch
`dec/214-profile-contract` carrying **ADR-0038 "The profile contract"** (status `proposed`, DEC-214
through DEC-221), which ratifies what code PR #38 shipped. Next free numbers are **DEC-222 /
ADR-0039** — not ≥205; the handoff's number came from a stale checkout on
`design/frontend-design-phase` (DEC-180).

So R-002 was never an absent decision. It is an **unreconciled** one, inside a single ADR:

- **DEC-215** kills `work_mode` with the sharpest line in the corpus — *"Two writable sources of
  truth for one fact is the defect; a dual-write window is that defect with a schedule attached."*
- **DEC-217** rejects a stored `embedding_stale` flag as *"the exact defect DEC-215 removes
  elsewhere."*
- **DEC-220**, two sections later, blesses four denormalized résumé columns as "server-owned
  derivations" — with no argument for the exemption.

And the drift path is authored by the same ADR: DEC-220 permits structured parsing to *"complete
later"*, which lands on `resume_uploads.parsed` while nothing re-syncs `user_profiles.resume_parsed`.

Separately, the wider stress-test found the exposure is not carried-forward v1 shapes — the corpus
has re-decided four of those on the record (`work_mode`, `comp_min_total`, `skills`,
`remote_preference`), two by deletion. The exposure is **dropped-forward**: fields v1 needed that v2
deleted with no decision anywhere. `users` has no name at all, and `googleOAuth.ts:110` discards the
Google ID token's `name`/`given_name`/`family_name` claims it already receives.

## Decisions taken (Davis, this session)

| # | Question | Ruling |
|---|---|---|
| R-002 | Résumé columns: cache or source of truth? | **Normalize.** All copies go; readers join through `resume_upload_id`. Subsumes R-001. |
| R-002b | Do the proposals columns follow? | **Yes.** Whole résumé unit lives in `resume_uploads`. |
| R-003 | What does `complete` structurally require? | **Nothing — status quo, documented.** No constraint; `complete` is a historical terminal fact. |
| Identity | Where does name/phone/linkedin land? | **Split.** Name on `users` now from the Google claim; phone/LinkedIn deferred to the consuming capability. |
| Placement | Where do the DECs go? | **Push ADR-0038 as-is, mint ADR-0039 / DEC-222+.** |

## Work — spec repo only. No code, no migrations this session.

Repo: `melting-co/melting-v2-spec`. Work from the fullest line —
`/Users/daviscohen/melting/code/planning/.worktrees/dec-214-profile-contract/melting-v2-spec_new/`
(branch `dec/214-profile-contract`, tip `e28672a`).

### 1. Accept and push ADR-0038 unchanged

Flip `decisions/0038-profile-contract.md:3` to `accepted` and push the branch. It is the true record
of what PR #38 shipped, including the compensation defect it already flags in Consequences — the
same flag-then-fix pairing that produced migration 018.

### 2. ADR-0039 — three DECs

New file `decisions/0039-*.md` following `decisions/0000-template.md`. House style is mandatory:
every DEC ends with an explicit `REJECTED:` clause naming the roads not taken.

**DEC-222 — the attached résumé is stored once; `user_profiles` carries only the pointer.**
Supersedes DEC-220's "server-owned derivations" clause. Six columns leave `user_profiles`:
`resume_text`, `resume_blob_key`, `resume_parsed`, `resume_parser_version`, `resume_proposals`,
`resume_proposals_confirmed_at`. `resume_upload_id` remains as the sole résumé column;
`resume_uploads` gains `proposals_confirmed_at`. Makes DEC-214's *"the résumé moves as one verified
unit"* structurally true rather than conventional. Two supporting facts worth recording: the
confirmation marker becomes per-upload, fixing a real loss (today `resume.ts:101` nulls it on every
attach, erasing that a prior résumé was ever confirmed); and the completion gate's résumé leg
reduces to `resume_upload_id IS NOT NULL`, because `resume_uploads_ready_is_extracted` already makes
"attached ⇒ non-empty extracted text" structural. *Rejected:* an explicitly-constrained cache
(Postgres cannot enforce copy-equals-source across tables; only a composite FK on `blob_key` is even
feasible, and text/parse stay unenforceable — convention where DEC-215 demands structure);
normalizing `resume_parsed` alone (leaves three facts copied and one joined, harder to explain than
either pure position); restructuring proposals as rows per Career's DEC-174 (larger than this
change, wants its own ADR).

**DEC-223 — `onboarding_status = 'complete'` is a historical terminal fact, not a current-validity
assertion.** Narrows DEC-219's *"an invalid current profile can never remain `complete`"* to the
finalization window it actually protects. That window **is** structural already — row lock, gate
re-check under it, and the `accepted_profile_version` guard at `refresh.ts:216-255`, plus
`profile_refresh_requests_complete_is_enqueued`. The five-requirement gate is an application
invariant evaluated at the finalization boundary only, and post-completion drift is expected and
harmless: a user who clears their target roles gets worse matches, not an ambiguous row. Records
that R-003's probe is true but demonstrates a *reachable* row, not a *harmful* one — contrast
compensation, where a null mode carrying a real floor is genuinely ambiguous, which is why #49 was a
real bug and this is not. *Rejected:* CHECKing all five legs (freezes today's product policy into
DDL, and the demotion it implies contradicts data-model §8.6's "no first-class re-onboarding state"
and would eject an editing user into the onboarding chat per 13-accounts §4); CHECKing only
`complete ⇒ resume_upload_id IS NOT NULL` (same category error at smaller scale — asserting current
state on a historical flag — and it would block any future partial-résumé-deletion operation).

**DEC-224 — user display name is account identity, captured at signup.** `users` gains name fields,
populated from the Google ID token claims already received and discarded at `googleOAuth.ts:110`.
Owned by `accounts/` per ADR-0035's split, not by `profile/` — DEC-28 pins `user_profiles` as
current *search inputs* and explicitly says the job-seeker is not a canonical `person`. Phone number
and LinkedIn URL are application-form data with no consumer until the extension executor
(ADR-0027) lands; they are deferred to the capability that needs them. Record the v1 evidence: v1
required name + LinkedIn to complete onboarding, and v1's cover-letter generator signed every PDF
*"Applicant"* (`cover_letter_manager.py:152`) because those fields were untyped — v2's answer was to
delete them rather than type them. Also record the cost window: `specs/build-week/28-v1-seed.md:20`
says *"users don't carry"*, so this is a free reversal now and expensive after first real signup.
*Rejected:* the full identity block now (phone/LinkedIn shape decided without their consumer in view
is the guess-ahead that produced 003's `work_mode`); a sixth `identity` profile section (blurs
DEC-28's boundary); deferring all of it (outreach W6 drafts "in the user's name" and would work
around the absence — how v1 got "Applicant").

### 3. Fold into the concern documents

Per `README.md:10-16`, the ADR is rationale and the concern docs are normative:
`data-model.md` §8.1 DDL + §8.6 + the completion-gate restatement · `13-accounts.md` §4 signup
bootstrap · `16-http-api.md` §7 if the proposals-confirm route's shape moves · `STATUS.md` coverage
line (next DEC **225**, next ADR **0040**).

**Numbering hazard:** re-grep before minting. DEC-206/207 are already double-minted across sibling
branches, and ADR-0036 anticipated exactly this — *"renumber at merge if a sibling branch minted
them first."* Do not trust the numbers in this plan without re-checking.

### 4. Update `agent_docs/revisit.md` (code repo)

- **R-001, R-002** → keep open, status changed to *decided by DEC-222, pending migration*. Per the
  register's own lifecycle, entries are removed by the PR that lands the fix, not by the DEC.
- **R-003** → move to **Resolved** as *not a defect*, citing DEC-223.
- **New entries**, each with the evidence the register requires:
  - **R-004** — `resume_uploads.status = 'attached'` is never demoted (`resume.ts:126-129`), so N
    replacements leave N rows claiming attached against one pointer. The R-002 shape, one table over.
  - **R-005** — `onboarding_step` is free text with no vocabulary and no CHECK, while
    `onboarding_status` got one in 016. Asymmetric, and it drives resume-where-you-left-off.
  - **R-006** — `voice_style_guide` is `jsonb` + `z.record(z.string(), z.unknown())`
    (`schema.ts:181`) with zero readers. Shape deferred to task 43's `inputs_hash` consumer; nothing
    currently records that it *is* deferred.
  - **R-007** — phone number and LinkedIn URL deferred per DEC-224, owed by the applications
    capability.

## Deferred to build runs — explicitly NOT this session

Two PRs, because migrations are one file per PR:

1. **Résumé normalization** — migration dropping the six columns and adding
   `resume_uploads.proposals_confirmed_at`; then `resume.ts`, `gate.ts`, `embedding.ts`, `purge.ts`,
   `columns.ts`, `types.ts`, `reads.ts`, and `profileSchema.pg.test.ts`'s
   `EXPECTED_PROFILE_COLUMNS` (28 entries, asserted with `toEqual` at line 121). `purge.ts`'s
   `Set` union of blob keys collapses to one source.
2. **Identity** — migration adding the name columns; `googleOAuth.ts` claim extraction;
   `bootstrap.ts:51` insert; `accountsSchema.pg.test.ts`.

**Migration numbering is not knowable from here.** 018 lives on PR #49 and is not on this branch,
and the handoff records that PRs #39/#40 carry migrations numbered 014/015 already taken on main.
Re-derive the next free prefix at build time.

**Straight drops follow existing precedent** — 014 and 015 both backfilled then dropped, and the
repo is pre-launch (013 guards that no row carries an embedding; no user data seeds from v1). Verify
that still holds before writing the migration rather than assuming it.

## Verification

No code this session, so verification is textual and structural:

- Re-grep max `DEC-`/`ADR-` across **all** spec branches immediately before minting; confirm 222–224
  and 0039 are still free.
- Confirm ADR-0039's DECs each carry a `REJECTED:` clause (house style, enforced by convention not
  tooling).
- Confirm every claim cited in the DECs against the code at the line referenced — the handoff
  records that a hand-copied constraint predicate produced a *wrong* answer last session, so cite
  from the file, never from memory.
- `agent_docs/revisit.md` renders and each new entry carries a `file:line`, a query result, or a
  failing probe. The register's own rule: an entry with no evidence is an opinion.
- The code repo gate is untouched this session; `make check` is not a meaningful signal here and
  should not be claimed as one.
