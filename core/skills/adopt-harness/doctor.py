#!/usr/bin/env python3
"""Verify that adoption actually ACTIVATED the hooks — CONTRACT §5's "trusted and
observed to fire", as close as it gets without launching a real session.

Usage: doctor.py <harness-root> <target-repo>

What the harness EXPECTS is read from the payload binding files themselves
(adopt/settings.json, adopt/codex/hooks.json) — they are the manifest; a
separate list would be a second copy to keep in sync. For every expected
(event, script) pair, per provider, the doctor answers three questions:

  present — does the script exist at .agents/hooks/ and is it executable?
  bound   — does that provider's binding file reference it under that event?
  fires   — invoked once with a benign payload (cwd = a scratch git repo, so
            nothing in the target is touched), does it exit 0? This catches
            "bound but crashes" and enforces the fail-open contract.

The payload stays the manifest of expectations; the target's .agents/MANIFEST
can only EXEMPT a script from them. One it tombstoned (`copy.sh --resolve
<path>=omit`) gets a neutral `–` row and no checks — without that, the
sanctioned omit could never reach a ✅. Absence is not the exemption: a script
missing with no tombstone is still red.

The payload cannot speak for a hook the harness RETIRED, so one more thing is
read off the target itself: any binding into .agents/hooks/ whose script does
not exist is red, expected or not — it runs a missing file on every event. The
row carries the exact entry to delete, on every run.

Any red row → exit 1, and copy.sh withholds its ✅. Codex trust is machine
state the doctor cannot grant, but it CAN see that ~/.codex/config.toml has no
trust entry for this repo's hooks.json and say so instead of staying silent.
"""
import json
import os
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True  # must precede the import — bindings.py owns the why
from bindings import homed_script  # noqa: E402

# Benign by construction: a no-op command, a markdown path (comment-bloat skips
# docs), no secrets. Every guard must let this through — a block here is a bug.
PAYLOADS = {
    "PreToolUse": {"tool_input": {"command": "true", "file_path": "README.md", "content": "hello"}},
    "PostToolUse": {"tool_input": {"command": "true", "file_path": "README.md", "content": "hello"}},
    "Stop": {"session_id": "harness-doctor"},
    "WorktreeCreate": {"name": "doctor-probe"},
}


def expected_bindings(payload_file):
    """[(event, script-basename)] in payload order."""
    with open(payload_file) as f:
        data = json.load(f)
    out = []
    for event, groups in data.get("hooks", {}).items():
        for g in groups:
            for h in g.get("hooks", []):
                out.append((event, os.path.basename(h["command"].strip('"'))))
    return out


def read_bindings(binding_files):
    """[(file, event, command)] across every readable file, or None if none is."""
    found = None
    for path in binding_files:
        if not os.path.isfile(path):
            continue
        try:
            with open(path) as f:
                data = json.load(f)
        except (json.JSONDecodeError, UnicodeDecodeError):
            continue
        found = found or []
        found += [
            (path, event, h["command"])
            for event, groups in data.get("hooks", {}).items()
            for g in groups
            for h in g.get("hooks", [])
        ]
    return found


def omitted_hooks(target):
    """Basenames under .agents/hooks/ that this repo's MANIFEST records as `omitted:<sha>`."""
    out = set()
    try:
        with open(os.path.join(target, ".agents", "MANIFEST")) as f:
            for line in f:
                digest, _, path = line.rstrip("\n").partition("  ")
                if digest.startswith("omitted:") and os.path.dirname(path) == ".agents/hooks":
                    out.add(os.path.basename(path))
    except OSError:
        pass
    return out


def fire(script, event, cwd):
    """Run the hook once with a benign payload; True iff it exits 0."""
    payload = json.dumps(PAYLOADS.get(event, {}))
    try:
        r = subprocess.run(
            [script], input=payload, capture_output=True, text=True, cwd=cwd, timeout=60
        )
        return r.returncode == 0, (r.stderr or "").strip().splitlines()[:1]
    except (subprocess.TimeoutExpired, OSError) as e:
        return False, [str(e)]


def main():
    root, target = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
    # Claude merges settings.json with settings.local.json at runtime — a hook bound in EITHER fires.
    providers = [
        ("claude", os.path.join(root, "adopt", "settings.json"),
         [os.path.join(target, ".claude", "settings.json"),
          os.path.join(target, ".claude", "settings.local.json")]),
        ("codex", os.path.join(root, "adopt", "codex", "hooks.json"),
         [os.path.join(target, ".codex", "hooks.json")]),
    ]
    hooks_dir = os.path.join(target, ".agents", "hooks")
    omitted = omitted_hooks(target)
    exempted = set()
    red = 0

    # One scratch repo for every firing: hooks resolve git/make against it, never the target.
    # It sits INSIDE the temp dir (not at its top) so route-worktree's <container>/worktrees
    # lands in the cleaned-up area, and it has a commit so a worktree can actually be cut.
    with tempfile.TemporaryDirectory() as tmp:
        scratch = os.path.join(tmp, "repo")
        subprocess.run(["git", "init", "-q", scratch], check=True, capture_output=True)
        subprocess.run(
            ["git", "-C", scratch, "-c", "user.email=d@d", "-c", "user.name=doctor",
             "commit", "-q", "--allow-empty", "-m", "init"],
            check=True, capture_output=True)
        fired = {}  # basename -> (ok, detail); scripts are shared, fire each once

        print(f"doctor: hook activation in {target}")
        for name, payload_file, binding_files in providers:
            expected = expected_bindings(payload_file)
            bindings = read_bindings(binding_files)
            bound = None if bindings is None else {
                (event, os.path.basename(command.strip('"'))) for _, event, command in bindings}
            rel = " + ".join(os.path.relpath(p, target) for p in binding_files if os.path.isfile(p)) \
                or os.path.relpath(binding_files[0], target)
            if bound is None:
                print(f"  {name} ({rel}) — MISSING or unparseable; nothing is bound")
            else:
                print(f"  {name} ({rel})")
            for event, script in expected:
                if script in omitted:
                    exempted.add(script)
                    print(f"    – {script:<32} omitted by this repo")
                    continue
                path = os.path.join(hooks_dir, script)
                problems = []
                if not os.path.isfile(path):
                    problems.append("script missing")
                elif not os.access(path, os.X_OK):
                    problems.append("not executable")
                else:
                    if script not in fired:
                        fired[script] = fire(path, event, scratch)
                    ok, detail = fired[script]
                    if not ok:
                        problems.append("crashed on a benign payload" + (f": {detail[0]}" if detail else ""))
                if bound is None or (event, script) not in bound:
                    problems.append(f"NOT BOUND under {event}")
                if problems:
                    red += 1
                    print(f"    ✗ {script:<32} {' · '.join(problems)}")
                else:
                    print(f"    ✓ {script:<32} {event} · fires clean")
            # An expected script that is missing already has its row; everything else bound
            # into the hook home with nothing behind it gets one here.
            rowed = {script for _, script in expected if script not in omitted}
            for path, event, command in bindings or []:
                script = homed_script(command)
                if not script or script in rowed or os.path.isfile(os.path.join(hooks_dir, script)):
                    continue
                red += 1
                print(f"    ✗ {script:<32} bound under {event} in {os.path.relpath(path, target)}, "
                      f"but .agents/hooks/{script} does not exist — remove that binding:")
                # Here, not only in the merge: copy.sh knows a hook was pruned for ONE run, then
                # the record is gone. This row is what a later run still has to go on.
                print(f"        \"command\": {json.dumps(command)}")

    codex_bindings = os.path.join(target, ".codex", "hooks.json")
    codex_config = os.path.expanduser("~/.codex/config.toml")
    if os.path.isfile(codex_bindings) and os.path.isfile(codex_config):
        with open(codex_config) as f:
            if f'"{codex_bindings}:' not in f.read():
                print(f"  ⚠ ~/.codex/config.toml has no trust entry for {codex_bindings}")
                print("    the next Codex session here will ask to trust these hooks — accept, or none of them run")

    if red:
        sys.stdout.flush()
        print(f"doctor: {red} red row(s) — adoption is NOT active", file=sys.stderr)
        return 1
    print("doctor: every hook present, bound in both providers, and fires clean"
          + (f" ({len(exempted)} omitted by this repo)" if exempted else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
