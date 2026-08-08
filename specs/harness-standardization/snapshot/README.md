# T0.1 — machine snapshot and checksum

**Task:** [`../plan/tasks.md`](../plan/tasks.md) § T0.1 · **Taken:** 2026-08-08 · **Regenerate:** `./snapshot.sh`

The pre-implementation audit artifact. Wave 1 rebuilds the machine tree, and ten skills exist
only on disk — this captures them before anything moves. Read-only against the machine; the
script writes nothing outside this directory.

**Content digest:** `4c4807c6d4be3a3c202a0024322b0b23d4b41645c8250e863dcb5ff845c4e1ea`
(sha256 of `MANIFEST-content.sha256`; re-running `snapshot.sh` reprints it).

---

## What was walked

T0.1 names four trees. `~/.claude` is a symlink to `~/agents/claude`, so `~/.claude/skills`
resolves to `~/agents/claude/skills` and is not a fourth unique tree. Three roots were walked and
nothing was counted twice — which is what the acceptance line's "every **unique** file" anticipates.

```text
~/.agents           →  trees/dot-agents/
~/.codex/skills     →  trees/codex-skills/
~/agents/claude     →  trees/claude-home/     (= ~/.claude, same inode)
```

**5471 unique files** were checksummed — every file under all three roots, nothing excluded.

## Two zones, two manifests

They have different consumers, so they are separate files rather than one 1 MB manifest.

| Manifest | Files | Copied into `trees/`? | Consumer |
| --- | --- | --- | --- |
| `MANIFEST-content.sha256` | 142 | yes (141 — see Secrets) | T0.2 import; `install.sh` drift checks |
| `MANIFEST-runtime.sha256` | 5329 | no | Wave 1 T1.4/T1.5 — the inventory taken before `~/agents/` is moved or retired |

**Content** = authored harness material: all of `~/.agents`; `~/.codex/skills` minus the
vendor-shipped `.system/`; and `~/agents/claude`'s `skills/ agents/ rules/ hooks/ commands/
plans/ scheduled-tasks/` plus its `settings*.json` / `mcp*.json`. This is the material that is
unrecoverable if lost.

**Runtime** = provider state and vendor-shipped files that a reinstall or a resumed session
regenerates: `projects/` (2332 session transcripts), `file-history/` (2001), `plugins/` (478),
`tasks/`, `paste-cache/`, `shell-snapshots/`, `telemetry/`, `backups/`, `sessions/`, `cache/`,
`uploads/`, `history.jsonl`, and `~/.codex/skills/.system/` (59).

⚠ **The runtime zone is checksummed but not copied.** 903 MB of session transcripts do not belong
in this repository. The manifest gives Wave 1 the exact inventory the cross-task rules require
before touching runtime state, and detects change — it does not restore it. Wave 1 T1.4 *moves*
this state (undoing the `~/.claude` symlink) rather than deleting it, so nothing here is scheduled
for destruction; if that changes, the content must be copied first.

## Reproducibility

Re-running against an unchanged machine reproduces `trees/` and `MANIFEST-content.sha256`
**byte-identically** — verified across three consecutive runs.

`MANIFEST-runtime.sha256` does **not** reproduce, by construction: it covers live provider state
that any running session mutates. Across the runs above, the only differences were in `projects/`
and `backups/` — this session's own transcript. Verify a re-run against the **content digest**,
not against the whole directory.

The script also verifies itself: after copying, it re-hashes every file in `trees/` against the
source checksum and fails loudly on any mismatch. All 141 matched.

## Secrets

`~/agents/claude/secrets.env` is **checksummed and never copied** — a checksum is not a secret
value. The script hard-fails if that file ever appears under `trees/`, and the assertion was
observed to pass. No secret value is written anywhere in this artifact.

`~/agents/claude/settings.json` was inspected before copying; it contains no credentials
(`env` holds only `CLAUDE_CODE_SCROLL_SPEED`).

---

## The ten unversioned skills

Skills present on disk and absent from the repo's `.claude/skills/`. Derived by set difference,
not copied from `DECISIONS-PENDING.md` — the result matches its list exactly.

| Skill | On disk in | Note |
| --- | --- | --- |
| `domain-modeling` | `~/.claude/skills`, `~/.codex/skills` | |
| `grill-with-docs` | `~/.claude/skills`, `~/.codex/skills` | T0.6 source |
| `grilling` | `~/.claude/skills`, `~/.codex/skills` | T0.6 source |
| `hatch-pet` | `~/.codex/skills` **only** | single source |
| `hot-mac` | `~/.claude/skills` **only** | single source; layer undecided (CONTRACT §5) |
| `prototype` | `~/.claude/skills`, `~/.codex/skills` | |
| `research` | `~/.claude/skills`, `~/.codex/skills` | |
| `setup-matt-pocock-skills` | `~/.claude/skills`, `~/.codex/skills` | |
| `teach` | `~/.claude/skills`, `~/.codex/skills` | |
| `wayfinder` | `~/.claude/skills`, `~/.codex/skills` | |

**The eight dual-sourced skills are byte-identical between the Claude and Codex copies**, so T0.2
has no reconciliation to do — either copy imports cleanly. `hatch-pet` and `hot-mac` each have
exactly one source, which is why `hot-mac` is called out as a unique unversioned source.

All ten are in `trees/`.

## The two drifted skills

`~/.agents/skills/` differs from the repo in exactly two files — `adopt-harness/SKILL.md` and
`docs-drift/SKILL.md` — confirming the fact recorded in `DECISIONS-PENDING.md`.

**The drift is not staleness, and this matters for Wave 1 T1.3.** All three copies were compared:

| Comparison | Result |
| --- | --- |
| `~/.claude/skills` vs repo, all 11 tracked skills | **in sync** |
| `~/.agents/skills` vs repo | drifted in 2 |
| `~/.agents/skills` vs `~/.claude/skills` | differ in the same 2 |

So `~/.agents/skills` is the odd copy out. Its two files carry a mechanical rewrite —
`CLAUDE.md` → `AGENTS.md` and `.claude/` → `.Codex/` — applied **in place to the installed
projection**, never to the repo source. Six substitutions in `adopt-harness/SKILL.md`, two in
`docs-drift/SKILL.md`.

⚠ **The rewrite is buggy.** It produced `.Codex/skills/adopt-harness/copy.sh` — wrong
capitalization, and the wrong directory besides, since the harness's skills live in
`.claude/skills/`. The installed copy therefore documents a path that does not exist.

This is exactly the failure the CONTRACT §5 frame exists to prevent ("`~/.agents/` is an installed
projection, **never edited in place**"), and it is why `install.sh` refuses on drift rather than
silently overwriting.

**Recorded, not acted on.** Reconciliation is Wave 1 T1.3. The evidence points one way — the repo
and `~/.claude/skills` agree, and the divergent copy is broken — but the *intent* behind the
rewrite (Codex reads `AGENTS.md`) is legitimate and is separately owned by T0.14's
`AGENTS.template.md`.

---

## Other observations for later waves

- **Machine-level Claude registers exactly one hook**, `inject-global-rules.sh` — the same
  one-hook state CONTRACT §5 records for machine-level Codex. Both are Wave 1 T1.8's starting
  point.
- **Two scheduled tasks exist on the machine**, `docs-drift-check` and `overview-fresh-check`.
  `overview-fresh` is retired by CONTRACT §5, so its scheduled task will point at a skill that no
  longer installs. Not in any current task's scope — flagged here.
- `~/.codex/config.toml`, `~/.codex/hooks.json`, and `~/.codex/AGENTS.md` are **outside T0.1's
  stated four trees and were not captured.** They are Wave 1 T1.8 inputs (hook registration and
  per-hash trust). Scope was left as written rather than widened; T1.8 should snapshot them first.

## Restoring a file

```sh
# what was captured, and its source path
grep 'hot-mac' MANIFEST-content.sha256

# restore (Wave 1 or later — not during Wave 0)
cp trees/claude-home/skills/hot-mac/SKILL.md ~/.claude/skills/hot-mac/SKILL.md

# verify any copy against the manifest
shasum -a 256 trees/claude-home/skills/hot-mac/SKILL.md
```
