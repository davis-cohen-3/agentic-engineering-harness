#!/usr/bin/env python3
"""Verify that adoption actually ACTIVATED the hooks — CONTRACT §5's "trusted and
observed to fire", as close as it gets without launching a real session.

Usage: doctor.py <harness-root> <target-repo>

What the harness EXPECTS is read from the payload binding files themselves
(adopt/settings.json, adopt/codex/hooks.json) — they are the manifest; a
separate list would be a second copy to keep in sync. For every expected
(event, script) pair, per provider, the doctor answers three questions:

  present — does the script exist at .claude/hooks/ and is it executable?
  bound   — does that provider's binding file reference it under that event?
  fires   — invoked once with a benign payload (cwd = a scratch git repo, so
            nothing in the target is touched), does it exit 0? This catches
            "bound but crashes" and enforces the fail-open contract.

Any red row → exit 1, and copy.sh withholds its ✅. Codex trust is machine
state the doctor cannot grant, but it CAN see that ~/.codex/config.toml has no
trust entry for this repo's hooks.json and say so instead of staying silent.
"""
import json
import os
import subprocess
import sys
import tempfile

# Benign by construction: a no-op command, a markdown path (comment-bloat skips
# docs), no secrets. Every guard must let this through — a block here is a bug.
PAYLOADS = {
    "PreToolUse": {"tool_input": {"command": "true", "file_path": "README.md", "content": "hello"}},
    "PostToolUse": {"tool_input": {"command": "true", "file_path": "README.md", "content": "hello"}},
    "Stop": {"session_id": "harness-doctor"},
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


def bound_set(binding_file):
    """{(event, script-basename)} actually bound in the target, or None if unreadable."""
    if not os.path.isfile(binding_file):
        return None
    try:
        with open(binding_file) as f:
            data = json.load(f)
    except (json.JSONDecodeError, UnicodeDecodeError):
        return None
    return {
        (event, os.path.basename(h["command"].strip('"')))
        for event, groups in data.get("hooks", {}).items()
        for g in groups
        for h in g.get("hooks", [])
    }


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
    providers = [
        ("claude", os.path.join(root, "adopt", "settings.json"), os.path.join(target, ".claude", "settings.json")),
        ("codex", os.path.join(root, "adopt", "codex", "hooks.json"), os.path.join(target, ".codex", "hooks.json")),
    ]
    hooks_dir = os.path.join(target, ".claude", "hooks")
    red = 0

    # One scratch repo for every firing: hooks resolve git/make against it, never the target.
    with tempfile.TemporaryDirectory() as scratch:
        subprocess.run(["git", "init", "-q", scratch], check=True, capture_output=True)
        fired = {}  # basename -> (ok, detail); scripts are shared, fire each once

        print(f"doctor: hook activation in {target}")
        for name, payload_file, binding_file in providers:
            expected = expected_bindings(payload_file)
            bound = bound_set(binding_file)
            rel = os.path.relpath(binding_file, target)
            if bound is None:
                print(f"  {name} ({rel}) — MISSING or unparseable; nothing is bound")
            else:
                print(f"  {name} ({rel})")
            for event, script in expected:
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
    print("doctor: every hook present, bound in both providers, and fires clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())
