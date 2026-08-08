---
name: overview-fresh
description: Check whether a hand-authored rendered overview (overview.html) still covers its source-of-truth decision log, and — interactively — regenerate it when behind. The overview carries a coverage stamp ("DEC 1–N", "ADRs 0001–00NN"); this compares that stamp to the spec's true max. Report-only when unattended; regenerates only on a yes. Use on demand ("is the overview fresh", "check overview drift") or as a scheduled hygiene run. Skip if there is no stamped overview.
argument-hint: "optional: path to the spec dir (the one holding overview.html, thoughts.md, decisions/)"
---

# overview-fresh — does the rendered overview still cover the spec?

STARTER_CHARACTER = 🗺️ — open each reply with it while this skill is active.

`overview.html` is HAND-AUTHORED (there is no spec→HTML generator), so it silently falls behind every
time a DECISION or ADR lands. Its header/footer carry a coverage **stamp** — that stamp is the freshness
contract. This skill checks the stamp against the spec's true max and, interactively, regenerates.
**Report-only when unattended** (flag, never auto-rewrite/commit the artifact). **Fresh is the common,
correct outcome** — prefer silence to a weak flag.

## Locate the spec (no hardcoded paths)
The **spec dir** is the one directory holding all three of `overview.html`, `thoughts.md`, and
`decisions/`. Resolve it in order: (1) the `$1` argument if given; (2) search down from the repo root
(`git rev-parse --show-toplevel`) for that trio; (3) if none, this repo has no stamped overview — exit
silently, nothing to do.

## The staleness check — run it, don't eyeball it
Run these as shell (deterministic — never infer the numbers by reading):
```sh
D="$SPEC_DIR"
spec_dec=$(grep -oE 'DECISION [0-9]+' "$D/thoughts.md" | grep -oE '[0-9]+' | sort -n | tail -1)
spec_adr=$(ls "$D/decisions" | grep -oE '^[0-9]{4}' | sort -n | tail -1)
ov_dec=$(grep -oE 'DEC 1[^0-9]{1,3}[0-9]+' "$D/overview.html" | grep -oE '[0-9]+$' | sort -n | tail -1)
ov_adr=$(grep -oE 'ADRs 0001[^0-9]{1,3}[0-9]{4}' "$D/overview.html" | grep -oE '[0-9]{4}$' | sort -n | tail -1)
```
Compare as base-10 integers (`$((10#$n))` — avoid the `0033`-as-octal trap). **Fail-closed:** if the
overview's stamp can't be parsed, treat it as stale (the contract is broken). Behind ⇔
`ov_dec < spec_dec` OR `ov_adr < spec_adr`.

## Fresh → say so briefly (or nothing, unattended)
`✅ overview fresh — DEC 1–<ov_dec>, ADRs 0001–<ov_adr> (spec at DEC-<spec_dec> / ADR-<spec_adr>)`.
Unattended: exit silently.

## Behind → depends on mode
Enumerate what's new since the stamp: the DECISIONS `> ov_dec` in `thoughts.md` and the ADR files
`> ov_adr` in `decisions/` (title lines). That set is exactly what the overview is missing.

- **Interactive** (a person invoked this): report the gap + the missing DEC/ADR titles, then offer to
  regenerate. On a yes: read those new DECs/ADRs, update the affected overview sections (add/adjust the
  content they change — don't just bump the number), **restamp** the header and footer to
  `ADRs 0001–<spec_adr, 4-digit> · DEC 1–<spec_dec>`, show the diff, and commit only on confirmation.
  Re-run the check after editing to prove it's green.
- **Unattended** (scheduled): do **NOT** rewrite or commit the artifact — regenerating an 85KB
  hand-authored file is a human-in-the-loop task. Flag it: open — or update, if one is already open —
  exactly ONE GitHub issue on the spec repo titled `Overview stale: N DEC / M ADR behind`, body listing
  the missing DEC/ADR titles and the one-line remedy ("run /overview-fresh and regenerate"). Dedupe
  against an existing open issue. Silent if fresh.

## Guardrails
- Report-only unattended; never `--force`; never regenerate without a yes.
- The stamp is the whole contract — if you regenerate, the restamp is mandatory, or the next run
  false-flags.
- This checks COVERAGE (does the stamp lag), not prose accuracy. Deep content-vs-spec auditing is a
  separate, heavier pass — don't silently expand scope into it.
