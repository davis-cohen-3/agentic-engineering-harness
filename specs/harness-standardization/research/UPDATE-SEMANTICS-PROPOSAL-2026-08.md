# Update semantics for adopted harness entries — proposal

**Status:** RATIFIED 2026-08-21 (verbally, from the melting review session), pending
implementation. Written 2026-08-21 out of the neutral-root architecture review run from melting.

Decisions taken with ratification:
- Three-way MANIFEST as specified below, over `git subtree`.
- `specs/README.md` moves to ONCE — repos own it after first write (resolves open question 2;
  melting's build-week rewrite stops being a conflict entirely).
- The four briefs in `~/.claude/agents/` stay, **owned by install.sh**: it installs/refreshes
  them explicitly, and the machine-layer docs state they provide default agents in un-adopted
  repos. The cross-tier shadowing surface is accepted knowingly.

Implementation defaults (not user decisions): the neutral-root restructure and the MANIFEST land
together, MANIFEST at `.agents/MANIFEST` (open question 1); `--check` learns to report
held/conflict counts from the MANIFEST (open question 3).

## Why this exists

`copy.sh` today has three ownership classes: FIXED (copied unconditionally), ONCE (written only
when absent), and hook BINDINGS (merged). Re-adoption is the supported upgrade path (decision O).
The two failure modes sit at the ends of that spectrum, and both are silent:

- **FIXED silently overwrites local intent.** Verified armed today: melting's `specs/README.md`
  (edited to carry build-week/burrow content) differs from `adopt/specs/README.md`, and `specs`
  is FIXED — the next `copy.sh` run against melting clobbers it without a word. The same class
  covers every hook script.
- **A naive "keep if locally modified" rule silently drops upstream fixes.** If FIXED were
  softened to fill-once-style keep, a security fix to a hook would never reach a repo that had
  ever touched that hook, and nothing would say so.

Both are two-way comparisons. The known-good answer (dpkg/RPM/git all converged on it) is a
**three-way** comparison: compare local and upstream against the *pristine* content recorded at
adoption. That requires recording pristine hashes — a MANIFEST.

## Verified facts this design relies on

Checked 2026-08-21, on this machine. Version-pinned; the canary below guards the undocumented ones.

| Fact | Evidence |
| --- | --- |
| Codex subagents follow a brief-by-pointer into a neutral root | 3/3 `codex exec` runs (codex-cli 0.147.0): toml `developer_instructions` pointed at `.agents/briefs/pointer-probe.md`; every run returned a secret present only in that file |
| Claude loads skills through a whole-directory `.claude/skills` symlink | Claude Code 2.1.223: skill listed AND body executed via `.claude/skills → ../.agents/skills`. **Undocumented behavior** — keep a gate canary (`test -L .claude/skills && test -e .claude/skills` plus one skill resolving) |
| Claude loads agents through per-file symlinks | 2.1.223: `.claude/agents/x.md → ../../.agents/briefs/x.md` — agent listed (frontmatter read) and brief body delivered to the spawned subagent |
| git preserves the symlinks through clone on POSIX | stored as mode `120000`; normal clone reproduces them. `core.symlinks=false` (Windows without dev mode, FS without symlinks) silently materializes a text file containing the target path — the canary is what catches this |

Consequences already banked from these: briefs need **no duplication and no generation** — one
neutral markdown file, Claude symlinks to it, Codex points at it; the byte-parity gate test in
`core/` becomes unnecessary. And the honest rationale for the neutral root is
**sandbox-complete + provider-symmetric**, *not* "no precedence rule is load-bearing" — user-level
tiers still exist and still shadow on dev machines (`~/.claude/agents/` ships four briefs into
every repo on this machine today).

## The design

One new ownership class, **MANAGED**, replaces FIXED for every entry a repo might legitimately
edit (hooks, specs templates, Makefile, gate examples). ONCE and hook-binding MERGE are unchanged.
The decision-O stamp is unchanged and complementary: the stamp answers "how far behind is this
repo" at repo level; the MANIFEST answers "which entries diverged" at entry level.

### MANIFEST

Written by `copy.sh` beside the version stamp. One line per managed entry, `shasum -a 256`
format, so verification is literally `shasum -c`:

```
<sha256-of-pristine-content>  <repo-relative-path>
omitted  <repo-relative-path>          # tombstone: repo deliberately removed this entry
```

The hash is of the content **as installed** (pristine), never updated by anything except an
install/refresh/resolution. `omitted` tombstones record a deliberate local deletion so it stays
quiet on future runs.

### The state table

Per managed entry: P = pristine hash in MANIFEST, L = local content hash, U = upstream (harness)
content hash.

| L vs P | U vs P | Action |
| --- | --- | --- |
| L = P | U = P | nothing — current |
| L = P | U ≠ P | **refresh**, record new pristine = U |
| L ≠ P | U = P | **keep local**, count it in the "held" report — the repo overrode it and upstream has nothing new |
| L ≠ P | U ≠ P | **CONFLICT** — keep local, report loudly, run exits nonzero and the ✅ is withheld |
| L absent, no tombstone | any | **CONFLICT** — a missing guardrail is indistinguishable from an accident; resolution may write a tombstone |
| L absent, tombstoned | U = P | quiet — deletion stands |
| L absent, tombstoned | U ≠ P | **CONFLICT** — upstream changed an entry this repo removed; re-decide |
| no P (new upstream entry) | — | install and record P; if a local file already occupies the path with different content → **CONFLICT** |
| P exists, entry gone upstream | L = P | prune the file, drop the MANIFEST line, note it |
| P exists, entry gone upstream | L ≠ P | leave the file, drop the MANIFEST line, note "now repo-own" |

Never silently keep across an upstream change; never silently overwrite a local change. Those two
rows are the entire point.

### Conflict resolution

Explicit, per path, never automatic:

```
copy.sh --resolve <path>=upstream <target>   # take the harness version, pristine := upstream
copy.sh --resolve <path>=local <target>      # keep the repo version — pristine := UPSTREAM,
                                             # so the entry reads as held and the NEXT upstream
                                             # change conflicts again (a new fix, a new decision)
copy.sh --resolve <path>=omit <target>       # write a tombstone (records the upstream hash too)
```

(Implementation note, found while testing: `=local` must record the *upstream* hash, never the
local one — recording local makes the entry read as unmodified, and the next plain run silently
refreshes over exactly the version the resolution chose to keep. "Pristine" precisely means "the
harness version this repo last reconciled against.")

(Flag naming is implementation detail; the property that matters is that resolution is a recorded
decision, not a side effect.)

### Critical entries

`adopt/CRITICAL` in the harness lists paths (hooks, typically) whose conflicts must not be
steppable-over: a conflict on a critical path makes `copy.sh` exit 1 **and** the adopt-harness
skill must not report ✅ until each is resolved explicitly. Fail-closed, never force-overwrite —
a forced write destroys local intent the harness cannot see; a blocked run puts a human in the
loop, which is what a security fix colliding with a local edit actually requires.

### Reporting

Every run prints coverage: `N current · M refreshed · K held · J conflicts`. "Held" is the drift
that decision O's stamp cannot see — without this line, a repo's harness coverage decays silently
as overrides accumulate.

## copy.sh sketch

The FIXED loop is replaced; directories (`adopt/hooks`, `adopt/specs`) are enumerated per file so
the state table applies per entry (the current `tar` pipe can neither detect conflicts nor prune):

```bash
MANIFEST="$TARGET/.claude/harness-manifest"   # or .agents/MANIFEST after the neutral-root move
sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
pristine() { grep -F "  $1" "$MANIFEST" 2>/dev/null | cut -d' ' -f1; }

for rel in $(managed_entries); do             # walks adopt/, emits repo-relative paths
  src="$ROOT/adopt-path-for/$rel" dst="$TARGET/$rel"
  P="$(pristine "$rel")" U="$(sha "$src")"
  L=""; [ -f "$dst" ] && L="$(sha "$dst")"
  case "" in esac  # decision per the state table:
  if [ -z "$P" ]; then
    if [ -n "$L" ] && [ "$L" != "$U" ]; then conflict "$rel new-vs-existing"
    else install_and_record "$rel" "$U"; fi
  elif [ "$P" = "omitted" ]; then
    [ "$U" = "$(omitted_pristine "$rel")" ] || conflict "$rel upstream-changed-omitted-entry"
  elif [ -z "$L" ]; then conflict "$rel missing"
  elif [ "$L" = "$P" ]; then
    [ "$U" = "$P" ] || { refresh "$rel"; record "$rel" "$U"; }
  else
    [ "$U" = "$P" ] && held "$rel" || conflict "$rel both-changed"
  fi
done
# exit 1 if any conflict; exit 1 unconditionally-blocking message if any critical conflict
```

~30 lines of real shell plus the walker and the resolution flags. No new dependencies
(`shasum` is on macOS and Linux both; the script already requires `python3`, which can carry the
MANIFEST read/write if grep-based parsing gets awkward).

## The alternative considered and set aside

`git subtree` of the adopt payload gives real three-way *content* merges, provenance, and
upstreaming for free — everything above is a hand-rolled subset. Set aside because: the adopt flow
already exists and works; subtree makes every repo's history carry harness commits and every
upgrade a `subtree pull` with squash/split ergonomics the team would be fighting in N repos; and
the harness deliberately supports non-git payload details (fill slots, merged bindings, doctor
verification) that subtree cannot express. Revisit only if per-entry hashes prove insufficient in
practice — i.e., if conflicts turn out to need *merging* rather than *choosing*.

## Open questions

1. Does the MANIFEST live at `.claude/harness-manifest` now and move to `.agents/MANIFEST` with
   the neutral-root restructure, or does the restructure land first? (Ordering only; the
   semantics are identical.)
2. Should `specs/README.md` stay MANAGED or move to ONCE? Melting's divergence suggests repos
   treat it as theirs — ONCE may match reality better than a held-forever MANAGED entry.
3. Does `--check` (decision O) learn to read the MANIFEST and report held/conflict counts without
   copying, so staleness checks see entry-level drift too?
