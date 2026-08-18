---
status: ready
audience: the operator running the Wave 1a machine session (with the developer present)
---

# Wave 1a — machine activation runbook

The **HOW** for [`tasks.md`](./tasks.md) rows T1.2–T1.10. Rationale, the settled decisions, and the
"why this order" live there and in [`../DECISIONS-PENDING.md`](../DECISIONS-PENDING.md) §M–P — this
file does not restate them; it is the command / verify / rollback sequence, so the session can move
without re-deriving anything. Where this file and `tasks.md` disagree, `tasks.md` wins.

This wave **activates** the converged harness. It touches no *live runtime state* — that is Wave 1b,
deferred (decision M). But T1.4a and the provider-settings steps swap directories the providers
read, so run them with **no live provider session**.

> ⚠ Lines marked **CONFIRM LIVE** depend on the machine's exact current layout, which this runbook
> was written away from. Look before you write; never assume the path.

---

## Preconditions — do not start until all hold

```sh
cd ~/dev/agentic-engineering
git switch main && git pull --ff-only
make check                      # green, all 5 suites
```

- **The preflight PRs are merged**: PF3–PF6, **and** the `wt` stdlib-registry fix (PR #8). That last
  one matters here: without it `wt` needs PyYAML to read the registry, and a Homebrew python bump
  has already removed PyYAML on this machine — `python3 -c 'import yaml'` failing is now fine.
- **The melting patch (PF2 / T2.3a) is shipped** — melting-co/melting-v2 PR #123. Independent of
  this wave; need not be merged first.
- **No live Claude or Codex session** for T1.4a and the provider-settings edits.
- **A terminal that is NOT inside any adopted repo**, for the inject-global-rules verification.
- **Backups you rely on already exist**: `install.sh` writes `~/.agents.prev`; T1.1 left
  `~/.config/git/ignore.pre-workspace.bak`. Confirm `~/.agents.prev` is not something you still need
  *before* the first `install.sh` run overwrites it.

## Order

`T1.9` is isolated — it needs nothing and may run **first**. Then:

```
T1.2 → T1.3 → T1.4a → T1.6 → T1.7 → T1.10
```

⚠ **Freeze registry edits between T1.6 and T2.1** (Depot reads the old registry, `wt` reads the new
one during that window) — or mirror any edit into both by hand. See `tasks.md` T1.6.

---

## T1.2 — machine secrets to `~/.config/agents/secrets.env`

Never move a secret **value** by script. Do this by hand; leave the old file in place until the new
path is verified end-to-end. (`tasks.md` T1.2, decision M.)

```sh
mkdir -p ~/.config/agents
umask 077 && : > ~/.config/agents/secrets.env      # created 600
chmod 600 ~/.config/agents/secrets.env
```

- **CONFIRM LIVE:** the old file's exact path (the spec says it currently sits inside
  `~/agents/claude/`). Open both files in an editor and **copy the contents across by hand** — do
  not `cat`/pipe it through a command that a shell history or log could capture.
- Edit `~/.zshrc`: add a `source ~/.config/agents/secrets.env` line. **Keep the old `source` line
  too** until verified.
- Update both rule files to reference the new path: `~/agents/claude/rules/00-preferences.md` and
  `.../secrets.md` (the "personal secrets live in …" line).

**VERIFY**
```sh
ls -l ~/.config/agents/secrets.env          # -rw------- (600)
zsh -lc 'echo ${SOME_KNOWN_VAR:+set}'        # prints: set   (pick a var the file defines)
```
No secret value appears in any file this session wrote, or in shell history.

**ROLLBACK** — remove the new `source` line from `~/.zshrc`; the old file and its source line are
untouched, so a new shell is back to the prior state. Delete `~/.config/agents/secrets.env`.

---

## T1.3 — reconcile `~/.agents/`, then install with `--prune`

Uses the `--review` channel built in PF4. **`--prune` never runs blind** — the review pass must
precede it and its stamp authorizes exactly one prune. The measured facts (8 refused, keep 4) are in
`tasks.md` "T1.3 — measured, not predicted".

```sh
cd ~/dev/agentic-engineering
./install.sh --dry-run          # re-confirm the 8 refusals + 4 keeps are still what T1.3 recorded
./install.sh --review           # walk the inbox
```

In the review inbox:

- **The 8 drifted files** — disposition is **repo-wins**: answer `p` (prune drift = restore from
  `core/`). **Read first, then `p`:** `adopt-harness/SKILL.md` and `docs-drift/SKILL.md` — T0.1 found
  the installed copy carries a buggy in-place rewrite (documents a `.Codex/` path that does not
  exist); confirm by eye that repo-wins is right, then `p`.
- **The retired kept extras** — `skills/grill-me/` and `skills/overview-fresh/` (retired by
  CONTRACT §5): answer `p` to delete, or leave them for `--prune` below. **CONFIRM LIVE** the other
  two keeps (e.g. `open-a-pr/`, now a project-layer skill) are wanted elsewhere or already gone
  before dropping them.

```sh
./install.sh                    # should now exit 0 — drift reconciled, nothing refused
./install.sh --prune            # drops the retired extras; consumes the review stamp
```

**VERIFY**
```sh
./install.sh --dry-run                                   # exit 0, no refusals, no keeps
ls ~/.agents/skills/grill-me ~/.agents/skills/overview-fresh 2>&1   # both: No such file
test -f ~/.agents/.install-manifest.sha256 && echo manifest-ok
test -d ~/.agents.prev && echo backup-present
```

**ROLLBACK** — `rm -rf ~/.agents && mv ~/.agents.prev ~/.agents`. A pruned skill is recoverable from
`~/.agents.prev` until the next install overwrites that backup.

---

## T1.4a — point the provider subdirs at `~/.agents/`, re-point the rules injection

Lay the symlinks **through the existing topology**: `~/agents/claude/skills` (etc.) *itself* becomes
the symlink into `~/.agents/`. A displaced real directory is **moved aside** (`.pre-harness`), never
deleted. Without this, Claude keeps reading the old real dirs and the machine never converges.
(`tasks.md` T1.4a.)

- **CONFIRM LIVE** which provider subdirs exist as real dirs today (`skills`, `agents`, and whether
  `rules`/`hooks` are provider-read here). For each such `~/agents/claude/<sub>`:

```sh
sub=skills                                   # repeat per confirmed subdir
src=~/agents/claude/$sub
if [ -L "$src" ]; then echo "already a link → $(readlink "$src")"; \
elif [ -e "$src" ]; then mv "$src" "$src.pre-harness" && ln -s ~/.agents/$sub "$src"; \
else ln -s ~/.agents/$sub "$src"; fi
```

- **Re-point the Claude SessionStart rules injection** to `~/.agents/hooks/inject-global-rules.sh`.
  **CONFIRM LIVE** where it currently points (a settings.json `SessionStart` hook entry). If left at
  the old tree it keeps injecting old rules **silently**, because the hook fails open. `tasks.md`
  T1.4a.

**VERIFY**
```sh
# a core skill resolves through the link from the provider's view
readlink ~/agents/claude/skills                          # → ~/.agents/skills
test -f ~/agents/claude/skills/tdd/SKILL.md && echo skill-resolves
```
- Start a session **outside any adopted repo** → the global rules appear, and they are the ones from
  `~/.agents/rules/` (check for a string only the new copy has).
- A core skill resolves from **both** providers.

**ROLLBACK** — `rm ~/agents/claude/<sub>` (the symlink) and `mv ~/agents/claude/<sub>.pre-harness
~/agents/claude/<sub>`. Re-point the injection hook back.

---

## T1.6 — activate the migrated registry

`install.sh` migrates `~/.config/depot/projects.yaml` → `~/.config/agents/projects.yaml` **only when
the target is absent** (it did this in T1.3 if it was absent). Activation is confirming `wt` and the
providers now read the new file.

```sh
test -f ~/.config/agents/projects.yaml && echo new-registry-present
```

**VERIFY** — cut a throwaway worktree in a **known** project and confirm it lands under the
registry's `worktree_root`, then remove it:

```sh
wt <known-project> --branch tmp/registry-check      # resolves via the new registry
# ... confirm the path it reported is under the registry worktree_root ...
git -C <known-project-repo> worktree remove <that-path>
git -C <known-project-repo> branch -D tmp/registry-check
```

⚠ **From here until T2.1, do not edit either registry** (or mirror edits into both). Depot still
reads `~/.config/depot/projects.yaml`.

**ROLLBACK** — `wt` falls back to `~/.config/depot/projects.yaml` if the new file is removed; deleting
`~/.config/agents/projects.yaml` reverts cleanly (Depot never stopped reading the old one).

---

## T1.7 — provider worktree roots + `WorktreeCreate`

GUI / settings, so **manual** and **CONFIRM LIVE**. Both degrade safely if absent (`tasks.md` T1.7).

- Claude Desktop: set the worktree **location**.
- Codex: set the worktree **root**.
- Register the `WorktreeCreate` hook so provider-created worktrees get `.workspace/`.

**VERIFY**
```sh
cd ~/dev/agentic-engineering && ./install.sh --dry-run | sed -n '/capabilit/,/worktree/p'
```
Then have a provider create a worktree and confirm it lands in the configured root **and** gets a
`.workspace/MISSION.md`.

**ROLLBACK** — clear the two settings; unregister the hook. Nothing else depends on them.

---

## T1.9 — Codex probes (isolated; may run first)

In a **disposable, trusted** repo — never a real project. Two questions, decided with data
(`tasks.md` T1.9, T0.16 #8):

```sh
d=$(mktemp -d)/probe && mkdir -p "$d" && cd "$d" && git init -q && git commit -q --allow-empty -m init
# adopt the harness so the repo carries the bindings
~/dev/agentic-engineering/core/skills/adopt-harness/copy.sh "$d" none
# ... trust the repo in Codex per its trust prompt ...
```

- **Probe A — plugin scoping:** does a project-scoped skill/plugin resolve under Codex here? Observe
  and record.
- **Probe B — hook exit code 127:** 127 is what a binding returns if `git rev-parse` fails inside the
  repo. Every hook fails **open** on a missing `jq`; 127 is the one dependency that degrades to
  undefined behaviour. Force it and observe how Codex treats it:

```sh
# temporarily point a Codex hook binding at a missing binary (or run where git rev-parse fails)
# and watch: does Codex treat 127 as allow, block, or error?
```

**VERIFY / OUTPUT** — record both results (a short findings note in `../` or the session log). This
step's deliverable is the **decision**, not a state change. Delete the disposable repo after.

**ROLLBACK** — none; nothing outside the disposable repo was touched.

---

## T1.10 — remove the orphaned `overview-fresh-check` scheduled task

`--prune` (T1.3) deleted the `overview-fresh` skill; the scheduled task that targets it now fails on
every firing. Remove it. **CONFIRM LIVE** the scheduling mechanism (cron / a routine / a provider
schedule).

**VERIFY** — the task no longer appears in the schedule listing; nothing fires against the deleted
skill.

**ROLLBACK** — re-add the schedule entry (but the skill is gone by design, so you would not).

---

## Wave 1a acceptance — all must hold (from `tasks.md`)

- [ ] both providers start cleanly in a neutral directory **and** in an adopted repo
- [ ] a core skill resolves through the symlink chain from **both** providers
- [ ] global rules inject from `~/.agents/rules/`
- [ ] every registered hook is **observed** to fire
- [ ] no secret value was written to any file
- [ ] `~/.agents.prev` exists
- [ ] the `--review` pass **preceded** `--prune`
- [ ] a rollback was **rehearsed** (kill a step mid-way and recover — see `tasks.md`; do it on T1.3
      or T1.4a, the two with the most moving parts)

## If a step goes wrong

Each step's ROLLBACK is local and reversible. The wave touches no live runtime state, so the
worst-case whole-wave revert is: restore `~/.agents.prev`, remove the new `~/.zshrc` source line,
undo the T1.4a symlinks (restore `.pre-harness`), and delete `~/.config/agents/projects.yaml`. The
machine is then exactly where it was before the session.
