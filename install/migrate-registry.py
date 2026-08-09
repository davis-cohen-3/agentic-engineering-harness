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


class ShapeError(Exception):
    """The registry is not the shape this line-based transform can safely edit."""


def _indent(line):
    return len(line) - len(line.lstrip())


def migrate(text):
    """Return (new_text, [descriptions of what changed]).

    Raises ShapeError rather than guessing. A line-based edit is only safe while the file has
    the shape it assumes, and this runs once against the only registry there is.
    """
    lines = text.splitlines(keepends=True)

    projects_at = next((i for i, l in enumerate(lines)
                        if l.strip().startswith("projects:") and _indent(l) == 0), None)
    if projects_at is None:
        raise ShapeError("no top-level 'projects:' key — refusing to guess where projects live")

    # The projects block runs until the next top-level key. Appending at EOF instead would land
    # the new project under whatever key happens to come last.
    end = len(lines)
    for i in range(projects_at + 1, len(lines)):
        if lines[i].strip() and _indent(lines[i]) == 0:
            end = i
            break

    out, changes, current_repo = [], [], None
    body = [l for l in lines[projects_at + 1:end] if l.strip()]
    key_indent = min((_indent(l) for l in body), default=2)

    for i, line in enumerate(lines):
        stripped = line.strip()
        in_projects = projects_at < i < end
        # A new project key resets the context. Without this, a project missing `repo:` would
        # inherit the previous one's and rewrite the WRONG entry's worktree_root.
        if in_projects and stripped.endswith(":") and _indent(line) == key_indent:
            current_repo = None
        if in_projects and stripped.startswith("repo:"):
            current_repo = stripped.split("repo:", 1)[1].strip()
        if in_projects and stripped.startswith("worktree_root:"):
            if current_repo is None:
                raise ShapeError(
                    f"line {i + 1}: 'worktree_root:' with no preceding 'repo:' in its project — "
                    "cannot tell which project it belongs to")
            if current_repo in WORKTREE_ROOTS:
                old = stripped.split("worktree_root:", 1)[1].strip()
                new = WORKTREE_ROOTS[current_repo]
                if old != new:
                    line = f"{line[:_indent(line)]}worktree_root: {new}\n"
                    changes.append(f"{current_repo}: {old} -> {new}")
        out.append(line)

    if "\n  depot:" not in "".join(out):
        block = DEPOT_BLOCK.strip("\n") + "\n"
        while end > projects_at + 1 and not out[end - 1].strip():
            end -= 1                      # insert before trailing blanks, not after them
        out[end:end] = [block]
        changes.append("added project: depot (~/dev/depot)")
    return "".join(out), changes


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
    try:
        migrated, changes = migrate(original)
    except ShapeError as e:
        print(f"migrate-registry: {e}", file=sys.stderr)
        print("  nothing was written; migrate this file by hand.", file=sys.stderr)
        return 1

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
