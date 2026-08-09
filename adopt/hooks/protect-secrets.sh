#!/usr/bin/env bash
# PreToolUse(Read|Edit|Write|apply_patch) guardrail: keep secrets out of the agent's context
# and out of new files.
#  - Reads:        block reading secret files (.env, keys, credentials).
#  - Edits/Writes: block touching those paths AND block writing a literal API key.
# Contract: exit 0 = allow, exit 2 = BLOCK. Falls OPEN if jq is missing.
#
# A HOOK, not a permission rule, so it survives a Warren `--dangerously-skip-permissions` run.
#
# The apply_patch fallback below is harvested from melting `origin/main`, blob
# 7687e47a0caa6a75cdf880cf8ae1e258c9dec979 (commit 4d554c16, 2026-08-02). Commit 95fa9b1 lives
# only on `origin/agent/codex-hook-matcher` and is deliberately NOT harvested.
#
# ONE DEVIATION from that blob, deliberate: it parses only the three `*** ... File:` headers, so a
# `*** Move to:` rename destination was never path-checked — an agent could write a benign file and
# rename it onto `.env`. Confirmed against codex 0.147.0, whose binary carries all four directives.
# Melting carries the same gap and needs the same fix.
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0   # fail OPEN

input="$(cat)"   # read stdin ONCE — a second `jq` would see an empty stream
deny() { echo "BLOCKED (secret protection): $1" >&2; exit 2; }

path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
content="$(printf '%s' "$input" | jq -r '.tool_input.content // .tool_input.new_string // empty')"

# Codex sends a whole patch (apply_patch) instead of Claude's file_path/content pair, so flatten
# every string in tool_input and take the targets from the patch headers. Same guard, both
# providers — without this the hook silently passes everything Codex writes. Flattening is gated
# on BOTH fields being empty so a Claude edit's old_string is never scanned: removing a secret
# must not be blocked as if it were adding one.
if [ -z "$path" ] && [ -z "$content" ]; then
  content="$(printf '%s' "$input" | jq -r '[.tool_input | .. | strings] | join("\n")' 2>/dev/null)"
fi
# `Move to:` is a rename destination: without it an agent writes an innocuous file and renames it
# onto a secret path, and the guard never sees where it landed. Leading whitespace is tolerated so
# an indented header cannot slip the anchor.
paths="$path
$(printf '%s' "$content" | sed -nE 's/^[[:space:]]*\*\*\* (Add|Update|Delete) File: //p; s/^[[:space:]]*\*\*\* Move to: //p')"

# 1. Sensitive PATHS — never read or write these.
while IFS= read -r p; do
  [ -z "$p" ] && continue
  case "$p" in
    *.env|*.env.*|*/.env|*/.env.*)                    deny "$p is an env/secret file" ;;
    */.git/config|*/.git/credentials)                 deny "$p holds git credentials" ;;
    *id_rsa|*id_ed25519|*.pem|*.key|*/.ssh/*)         deny "$p is a private key / SSH material" ;;
    *.aws/credentials|*.netrc|*credentials.json)      deny "$p holds stored credentials" ;;
  esac
done <<< "$paths"

# 2. Literal SECRET VALUES in new content — don't let a real key get written to a file.
if [ -n "$content" ]; then
  if printf '%s' "$content" | grep -Eq \
    'sk-[A-Za-z0-9]{20,}|sk-ant-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----'; then
    deny "the content contains what looks like a real API key / private key. Use a \${VAR} reference instead."
  fi
fi

exit 0
