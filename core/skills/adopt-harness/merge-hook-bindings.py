#!/usr/bin/env python3
"""Merge harness hook bindings into a repo's binding file.

Usage: merge-hook-bindings.py [--gone <script>]... <payload.json> <dest.json> [<sibling.json>...]

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

The merge only ever ADDED, so a script that went away left its binding behind,
running a missing file on every event (harness #19, found in melting v3). Each
--gone <script> names one that is DELIBERATELY gone from .agents/hooks/ — pruned
because the harness retired it, or omitted by this repo; copy.sh decides which,
and never names a script that still exists. For each, the binding to
.agents/hooks/<script> is removed from dest, along with a group or event key
that removal emptied, and the payload's own entry for it is not merged. Only that
exact path matches (bindings.homed_script): the same basename anywhere else is
the repo's own and survives. A sibling is STILL never written — a dead binding
there is printed with the exact entry to delete, and the doctor holds the ✅.
That print happens ONCE: copy.sh can name a pruned script only on the run that
prunes it. The doctor's red row repeats the entry on every run after.

Prints a summary line for copy.sh to relay, then any sibling report, indented to
sit under it. Exit 0 on success, 1 on a dest file that exists but cannot be
parsed (adoption must stop, not guess).
"""
import json
import os
import sys

sys.dont_write_bytecode = True  # must precede the import — bindings.py owns the why
from bindings import homed_script  # noqa: E402


def basename(cmd):
    return os.path.basename(cmd.strip('"'))


def unbind(events, gone):
    """Drop dest's bindings to a gone script; returns how many. A group or event key is dropped
    only when THIS emptied it — one that was already empty is the repo's own shape."""
    removed = 0
    for event in list(events):
        for group in list(events[event]):
            hooks = group.get("hooks", [])
            keep = [h for h in hooks if homed_script(h["command"]) not in gone]
            if len(keep) == len(hooks):
                continue
            removed += len(hooks) - len(keep)
            group["hooks"] = keep
            if not keep:
                events[event] = [g for g in events[event] if g is not group]
                if not events[event]:
                    del events[event]
    return removed


def main():
    args, gone = sys.argv[1:], set()
    while args and args[0] == "--gone":
        gone.add(args[1])
        args = args[2:]
    payload_path, dest_path, siblings = args[0], args[1], args[2:]
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
    sibling_bound, sibling_dead = {}, []
    for s in siblings:
        try:
            with open(s) as f:
                d = json.load(f)
        except (OSError, json.JSONDecodeError, UnicodeDecodeError):
            continue
        for event, groups in d.get("hooks", {}).items():
            for g in groups:
                for h in g.get("hooks", []):
                    if homed_script(h["command"]) in gone:
                        sibling_dead.append((s, event, h["command"]))
                    sibling_bound.setdefault(event, set()).add(basename(h["command"]))

    events = dest.setdefault("hooks", {})
    removed = unbind(events, gone)
    merged, updated, already, omitted = 0, 0, 0, 0
    for event, groups in payload.get("hooks", {}).items():
        # .get, not .setdefault: an event this run adds nothing under must not appear as an
        # empty key — that is how an omitted hook's event would come straight back.
        dest_groups = events.get(event, [])
        # dest is the harness-managed file, so an entry with our script but a stale
        # command form is OURS to upgrade in place; a sibling's entry never is.
        ours = {basename(h["command"]): h for g in dest_groups for h in g.get("hooks", [])}
        for group in groups:
            for hook in group.get("hooks", []):
                name = basename(hook["command"])
                if name in gone:
                    omitted += 1     # still in the payload yet gone: only an omit does that
                    continue
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
                events[event] = dest_groups
                ours[name] = hook
                merged += 1

    tail = f", {omitted} omitted by this repo" if omitted else ""
    if merged or updated or removed:
        os.makedirs(os.path.dirname(dest_path) or ".", exist_ok=True)
        with open(dest_path, "w") as f:
            json.dump(dest, f, indent=2)
            f.write("\n")
        parts = []
        if merged:
            parts.append(f"created with {merged} binding(s)" if created else f"merged {merged} binding(s)")
        if updated:
            parts.append(f"updated {updated} stale command(s)")
        if removed:
            parts.append(f"removed {removed} dead binding(s)")
        if already:
            parts.append(f"{already} already bound")
        print(", ".join(parts) + tail)
    else:
        print(f"all {already} binding(s) already bound" + tail)

    for s, event, command in sibling_dead:
        rel = os.path.join(os.path.basename(os.path.dirname(s)), os.path.basename(s))
        print(f"    ⚠ {rel} still binds {event} to .agents/hooks/{homed_script(command)}, which is gone.")
        print("      That file is the team's — adoption never writes it. Delete this hook entry from it:")
        print(f"        \"command\": {json.dumps(command)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
