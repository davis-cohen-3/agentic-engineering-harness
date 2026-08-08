# `packs/` — carried, opt-in, not machine-installed

Skills the harness **versions but does not install globally**. `core/` is published to
`~/.agents/` by `install.sh`; nothing here is. A project or provider opts in by copying a pack
into its own `.claude/skills/`.

Layer assignments come from the catalog in [`../specs/harness-standardization/CONTRACT.md`](../specs/harness-standardization/CONTRACT.md) §5.
Placement is decided by **portability** — *would this be correct and useful in a repository I have
never seen, with zero configuration?* Everything here answers no, or is not installed at all.

| Directory | Layer | Contents |
| --- | --- | --- |
| `project/` | Project | `domain-modeling`, `setup-matt-pocock-skills`, `wayfinder` |
| `area/` | Area pack | `teach` |
| `retired/` | Retired | `grill-with-docs`, `grilling`, `hatch-pet` |
| `unassigned/` | **undecided** | `hot-mac` |

## `retired/` — preserved, never installed

These are kept as **source**, not as installable skills. `grill-with-docs` and `grilling` are the
inputs T0.6 merges into the single core `grill` (with `grill-me`, which was already versioned);
`hatch-pet` is retired outright and has no successor. They are here because they existed only on
an unversioned machine tree and deleting them would have been unrecoverable — not because anything
still loads them.

## `unassigned/hot-mac`

**Layer deliberately undecided.** CONTRACT §5 lists it as *"unique unversioned source; preserve
first, decide later"*, and the decision is deferred to Wave 3 T3.2. It was the only skill present
in `~/.claude/skills` and nowhere else, so preservation had to precede the choice. Its presence
here is not an assignment.

---

⚠ **`packs/` is a T0.2 mechanics decision, not a settled one.** CONTRACT §5 assigns skills to five
layers but its source layout names homes only for `core/` and `adopt/`, leaving the non-core layers
without a versioned home — while T0.2's acceptance requires that no skill exist only on disk. This
directory closes that gap and is the smallest structure that does so. If T0.3 or a later decision
gives these layers a different home, move them; nothing depends on this path yet.

## Provenance

Every file here was imported from the T0.1 snapshot at
[`../specs/harness-standardization/snapshot/`](../specs/harness-standardization/snapshot/) and
verified byte-for-byte against its recorded on-machine checksum. The eight skills that existed in
both `~/.claude/skills` and `~/.codex/skills` were byte-identical in both, so the copies are
unambiguous. `hatch-pet` came from `~/.codex/skills` and `hot-mac` from `~/.claude/skills`, each
being that skill's only source.
