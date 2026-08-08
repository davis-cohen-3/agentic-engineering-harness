# `core/` — the machine payload

Published to `~/.agents/` by `install.sh`. Everything here must pass the portability test from
[`../specs/harness-standardization/CONTRACT.md`](../specs/harness-standardization/CONTRACT.md) §5:

> would this be correct and useful in a repository I have never seen, with zero configuration?

Nothing here is specific to this repository, and nothing here is copied into a target repo — that
is [`../adopt/`](../adopt/). Skills that are useful but *not* universal live in
[`../packs/`](../packs/).

```text
core/
  skills/          shared — both providers read SKILL.md
  hooks/           shared — one script, two bindings
  rules/           injected by inject-global-rules.sh
  claude/agents/   4 × .md + frontmatter
  codex/agents/    4 × .toml + developer_instructions
```

## The eight agent files

Four agents, two provider formats, **no generator** — a change to an agent touches both files.
The `.toml` `developer_instructions` bodies are byte-identical to their `.md` counterparts apart
from a trailing newline; that was verified at import and is the invariant to preserve.

## `~/.agents/` is a projection, never a source

`install.sh` writes this tree to the machine and refuses to run when a file there differs from its
source here. Editing `~/.agents/` directly is how the two skills recorded in
[`../specs/harness-standardization/snapshot/`](../specs/harness-standardization/snapshot/) came to
carry a broken path. Change `core/`, then install.

## Provenance

`hooks/inject-global-rules.sh` and `rules/*.md` were unversioned machine content until T0.3;
`codex/agents/*.toml` until the T0.1 addendum. All were imported from the T0.1 snapshot and
verified against their recorded on-machine checksums.
