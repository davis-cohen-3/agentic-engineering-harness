#!/usr/bin/env python3
"""Merge harness hook bindings into a repo's binding file.

Usage: merge-hook-bindings.py <payload.json> <dest.json> [<sibling.json>...]

A sibling is a file the provider ALSO reads (Claude merges settings.json with
settings.local.json at runtime): a hook already bound there counts as bound, so
it is not duplicated into dest. Siblings are read, never written.

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
    siblings = sys.argv[3:]
    with open(payload_path) as f:
        payload = json.load(f)

    created = not os.path.exists(dest_path)
    if created:
        dest = {}
    else:
        try:
            with open(dest_path) as f:
                dest = json.load(f)
        except (json.JSONDecodeError, UnicodeDecodeError) as e:
            print(f"✗ cannot parse {dest_path} — fix it and re-run ({e})", file=sys.stderr)
            return 1

    # An unparseable sibling binds nothing at runtime either, so it is skipped, not fatal.
    sibling_bound = {}
    for s in siblings:
        try:
            with open(s) as f:
                d = json.load(f)
        except (OSError, json.JSONDecodeError, UnicodeDecodeError):
            continue
        for event, groups in d.get("hooks", {}).items():
            for g in groups:
                for h in g.get("hooks", []):
                    sibling_bound.setdefault(event, set()).add(basename(h["command"]))

    events = dest.setdefault("hooks", {})
    merged, updated, already = 0, 0, 0
    for event, groups in payload.get("hooks", {}).items():
        dest_groups = events.setdefault(event, [])
        # dest is the harness-managed file, so an entry with our script but a stale
        # command form is OURS to upgrade in place; a sibling's entry never is.
        ours = {basename(h["command"]): h for g in dest_groups for h in g.get("hooks", [])}
        for group in groups:
            for hook in group.get("hooks", []):
                name = basename(hook["command"])
                if name in sibling_bound.get(event, set()):
                    already += 1
                    continue
                if name in ours:
                    if ours[name]["command"] != hook["command"]:
                        ours[name]["command"] = hook["command"]
                        updated += 1
                    else:
                        already += 1
                    continue
                matcher = group.get("matcher")
                target = next((g for g in dest_groups if g.get("matcher") == matcher), None)
                if target is None:
                    target = {"hooks": []} if matcher is None else {"matcher": matcher, "hooks": []}
                    dest_groups.append(target)
                target["hooks"].append(hook)
                ours[name] = hook
                merged += 1

    if merged or updated:
        os.makedirs(os.path.dirname(dest_path) or ".", exist_ok=True)
        with open(dest_path, "w") as f:
            json.dump(dest, f, indent=2)
            f.write("\n")
        parts = []
        if merged:
            parts.append(f"created with {merged} binding(s)" if created else f"merged {merged} binding(s)")
        if updated:
            parts.append(f"updated {updated} stale command(s)")
        if already:
            parts.append(f"{already} already bound")
        print(", ".join(parts))
    else:
        print(f"all {already} binding(s) already bound")
    return 0


if __name__ == "__main__":
    sys.exit(main())
