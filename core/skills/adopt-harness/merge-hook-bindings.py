#!/usr/bin/env python3
"""Merge harness hook bindings into a repo's binding file.

Usage: merge-hook-bindings.py <payload.json> <dest.json>

Bindings REGISTER BEHAVIOUR, so unlike CLAUDE.md/gate.mk they can never be
fill-once: a repo that already had one provider's file and not the other would
end up in two different governance states from a single ✅ run (the smoke
failure, 2026-08-21). Instead the payload is merged in, keyed by
(event, script basename) — basename because the two providers prefix the same
script differently ($CLAUDE_PROJECT_DIR/... vs "$(git rev-parse ...)"/...).

The repo's own entries are never touched, and only the "hooks" key is examined —
permissions and anything else in settings.json pass through untouched. A hook
already bound (under any matcher) is left exactly where the repo put it.
Idempotent: a second run writes nothing.

Prints one summary line for copy.sh to relay. Exit 0 on success, 1 on a dest
file that exists but cannot be parsed (adoption must stop, not guess).
"""
import json
import os
import sys


def basename(cmd):
    return os.path.basename(cmd.strip('"'))


def main():
    payload_path, dest_path = sys.argv[1], sys.argv[2]
    with open(payload_path) as f:
        payload = json.load(f)

    if not os.path.exists(dest_path):
        os.makedirs(os.path.dirname(dest_path) or ".", exist_ok=True)
        with open(dest_path, "w") as f:
            json.dump(payload, f, indent=2)
            f.write("\n")
        n = sum(len(g.get("hooks", [])) for gs in payload.get("hooks", {}).values() for g in gs)
        print(f"created with {n} binding(s)")
        return 0

    try:
        with open(dest_path) as f:
            dest = json.load(f)
    except (json.JSONDecodeError, UnicodeDecodeError) as e:
        print(f"✗ cannot parse {dest_path} — fix it and re-run ({e})", file=sys.stderr)
        return 1

    events = dest.setdefault("hooks", {})
    merged, already = 0, 0
    for event, groups in payload.get("hooks", {}).items():
        dest_groups = events.setdefault(event, [])
        bound = {basename(h["command"]) for g in dest_groups for h in g.get("hooks", [])}
        for group in groups:
            for hook in group.get("hooks", []):
                if basename(hook["command"]) in bound:
                    already += 1
                    continue
                matcher = group.get("matcher")
                target = next((g for g in dest_groups if g.get("matcher") == matcher), None)
                if target is None:
                    target = {"hooks": []} if matcher is None else {"matcher": matcher, "hooks": []}
                    dest_groups.append(target)
                target["hooks"].append(hook)
                bound.add(basename(hook["command"]))
                merged += 1

    if merged:
        with open(dest_path, "w") as f:
            json.dump(dest, f, indent=2)
            f.write("\n")
        print(f"merged {merged} binding(s)" + (f", {already} already bound" if already else ""))
    else:
        print(f"all {already} binding(s) already bound")
    return 0


if __name__ == "__main__":
    sys.exit(main())
