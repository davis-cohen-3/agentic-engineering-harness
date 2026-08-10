# Patches for other repositories

Fixes this epic found in a repo it does not own. They live here so they are versioned and
reviewable rather than buried in a report, and so applying one stays **the developer's action** —
Wave 0's constraint is harness-repo-only.

## `melting-protect-secrets-move-to.patch` — CRITICAL

**What:** melting's `.claude/hooks/protect-secrets.sh` parses only the three `*** … File:` headers
of a Codex `apply_patch`, so a `*** Move to:` **rename destination is never path-checked**. An
agent can write an innocuous file and rename it onto `.env` or a private key, and the guard
returns **exit 0**.

This is the same defect found and fixed in this harness (T0.16, finding S1) — the harness
inherited it by harvesting melting's blob `7687e47a0caa6a75cdf880cf8ae1e258c9dec979`. It is an
upstream bug, not a transcription error, which is why both copies need it.

**Verified before writing this patch:**

| Check | Result |
| --- | --- |
| `*** Move to:` is real Codex grammar | Present in the `codex 0.147.0` binary alongside the three `File:` directives |
| melting `origin/main` today, rename onto `.env` | **exit 0** — the live hole |
| with this patch applied | **exit 2**, `BLOCKED (secret protection): /r/.env is an env/secret file` |
| ordinary `apply_patch` edit, patched | **exit 0** — no false positive |
| `git apply --check` against `origin/main` content | clean |

The patch also tolerates leading whitespace, so an indented header cannot slip the `^` anchor.

## Applying it

Targets **`origin/main`** (blob `7687e47a…`, commit `4d554c16`). From melting's root:

```sh
git switch -c fix/protect-secrets-move-to origin/main
git apply /path/to/agentic-engineering/specs/harness-standardization/patches/melting-protect-secrets-move-to.patch
```

⚠ **Do not apply it to `chore/melting-v2-docs-harness` as it stands.** That branch is **27 commits
behind** `origin/main` and predates the `apply_patch` fallback entirely (commit `4d554c16` is not
an ancestor), so the file there has no patch-header parsing at all and this diff will not apply.
That branch is not a revert — it simply branched earlier. Merging or rebasing `origin/main` brings
the fallback in, and the `Move to:` gap with it.

Nothing in this repository applies the patch. Nothing checks that it was applied.
