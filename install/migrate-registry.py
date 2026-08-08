#!/usr/bin/env python3
"""Promote ~/.config/depot/projects.yaml to ~/.config/agents/projects.yaml.

Same file, same format, new path — plus the two edits decision A calls for: the worktree_root
values move to the <container>/worktrees/ layout, and the missing `depot` project is added.

The transform is LINE-BASED on purpose. Round-tripping through PyYAML would parse and reparse
correctly but silently drop every comment and the `profiles:` block's formatting, and this file is
hand-edited. Only the lines that must change are touched; everything else is preserved byte for
byte.

Never overwrites an existing target, and never modifies the source.

    migrate-registry.py <source> <target> [--dry-run]
"""
import os
import sys

# repo path -> new worktree_root. A container holding more than one repo gets a <repo> level,
# which is why ~/dev and ~/melting/code have one and ~/smoke/code does not: a flat root would
# collide between two projects in the same container.
WORKTREE_ROOTS = {
    "~/smoke/code/smoke-screen": "~/smoke/code/worktrees",
    "~/melting/code/v1": "~/melting/code/worktrees/v1",
    "~/melting/code/melting-v2": "~/melting/code/worktrees/melting-v2",
    "~/dev/agentic-engineering": "~/dev/worktrees/agentic-engineering",
}

DEPOT_BLOCK = """
  depot:
    repo: ~/dev/depot
    worktree_root: ~/dev/worktrees/depot
    setup_cmd: uv sync
    # no dev_cmd — the daemon is launched per-worktree, not by the registry
"""


def migrate(text):
    """Return (new_text, [descriptions of what changed])."""
    lines = text.splitlines(keepends=True)
    out, changes, current_repo = [], [], None

    for line in lines:
        stripped = line.strip()
        if stripped.startswith("repo:"):
            current_repo = stripped.split("repo:", 1)[1].strip()
        if stripped.startswith("worktree_root:") and current_repo in WORKTREE_ROOTS:
            old = stripped.split("worktree_root:", 1)[1].strip()
            new = WORKTREE_ROOTS[current_repo]
            if old != new:
                indent = line[: len(line) - len(line.lstrip())]
                line = f"{indent}worktree_root: {new}\n"
                changes.append(f"{current_repo}: {old} -> {new}")
        out.append(line)

    text = "".join(out)
    if "\n  depot:" not in text:
        if not text.endswith("\n"):
            text += "\n"
        text += DEPOT_BLOCK
        changes.append("added project: depot (~/dev/depot)")
    return text, changes


def main(argv):
    args = [a for a in argv[1:] if not a.startswith("--")]
    dry = "--dry-run" in argv
    if len(args) != 2:
        print(__doc__.strip().splitlines()[-1].strip(), file=sys.stderr)
        return 2
    source, target = (os.path.expanduser(a) for a in args)

    if not os.path.isfile(source):
        print(f"migrate-registry: no source registry at {source}", file=sys.stderr)
        return 1
    if os.path.exists(target):
        print(f"migrate-registry: target already exists, left untouched: {target}")
        return 0

    with open(source) as f:
        original = f.read()
    migrated, changes = migrate(original)

    for c in changes:
        print(f"  {c}")
    if not changes:
        print("  no changes needed")

    if dry:
        print(f"  dry run — would write {target}")
        return 0

    os.makedirs(os.path.dirname(target), exist_ok=True)
    with open(target, "w") as f:
        f.write(migrated)
    print(f"  wrote {target}")

    with open(source) as f:
        if f.read() != original:
            print("migrate-registry: SOURCE WAS MODIFIED", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
