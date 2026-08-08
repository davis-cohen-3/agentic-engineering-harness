---
name: overview-fresh-check
description: Daily coverage-stamp freshness check for the melting-v2 spec overview — runs the overview-fresh skill unattended, files a GitHub issue if the overview lags the spec.
---

Run the `overview-fresh` skill in UNATTENDED mode against the melting v2 spec repo's rendered overview.

Spec dir: /Users/daviscohen/melting/code/planning/melting-v2-spec_new — it holds overview.html, thoughts.md, and decisions/. GitHub repo for issues: melting-co/melting-v2-spec (default branch main).

The skill is the source of truth for the procedure — its full instructions are at /Users/daviscohen/.claude/skills/overview-fresh/SKILL.md. Read that file and follow it. In brief:

1. cd into the spec dir. Best-effort refresh: `git fetch -q origin && git pull --ff-only 2>/dev/null || true` (if it can't fast-forward, just proceed on the working tree — do NOT stash, merge, or force anything).
2. Run the deterministic staleness check (do NOT eyeball the numbers — run the shell): the spec's true max = highest `DECISION N` in thoughts.md and highest `NNNN` ADR filename in decisions/; the overview's claim = the `DEC 1–N` and `ADRs 0001–00NN` coverage stamp in overview.html. Compare as base-10 integers. Fail-closed: if the overview's stamp can't be parsed, treat it as stale.
3. If the overview's stamp is current (not behind on either DEC or ADR), exit SILENTLY — no issue, no output.
4. If it lags, do NOT regenerate or commit the overview — regenerating an 85KB hand-authored artifact is a human-in-the-loop task. Instead open — or update, if one is already open — exactly ONE GitHub issue on melting-co/melting-v2-spec titled "Overview stale: N DEC / M ADR behind", body listing the missing DECISION/ADR titles (those numbered above the overview's stamp, read from thoughts.md / decisions/) and the one-line remedy: "run /overview-fresh interactively and regenerate". Dedupe against any existing open "Overview stale" issue rather than filing a second.

Report-only: never regenerate or commit the overview unattended, never force-push, never edit the spec. Silent when fresh. Do not run builds, tests, or make check — this is a bounded daily hygiene flag.