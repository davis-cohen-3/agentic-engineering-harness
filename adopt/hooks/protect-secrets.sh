#!/usr/bin/env bash
# PreToolUse(Read|Edit|Write) guardrail: keep secrets out of the agent's context
# and out of new files.
#  - Reads:        block reading secret files (.env, keys, credentials).
#  - Edits/Writes: block touching those paths AND block writing a literal API key.
# Contract: exit 0 = allow, exit 2 = BLOCK. Falls OPEN if jq is missing.
#
# A HOOK, not a permission rule, so it survives a Warren `--dangerously-skip-permissions` run.
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0   # fail OPEN

input="$(cat)"   # read stdin ONCE — a second `jq` would see an empty stream
path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
# New content being written (Write.content or Edit.new_string), if any.
content="$(printf '%s' "$input" | jq -r '.tool_input.content // .tool_input.new_string // empty')"

deny() { echo "BLOCKED (secret protection): $1" >&2; exit 2; }

# 1. Sensitive PATHS — never read or write these.
case "$path" in
  *.env|*.env.*|*/.env|*/.env.*)                      deny "$path is an env/secret file" ;;
  */.git/config|*/.git/credentials)                   deny "$path holds git credentials" ;;
  *id_rsa|*id_ed25519|*.pem|*.key|*/.ssh/*)           deny "$path is a private key / SSH material" ;;
  *.aws/credentials|*.netrc|*credentials.json)        deny "$path holds stored credentials" ;;
esac

# 2. Literal SECRET VALUES in new content — don't let a real key get written to a file.
if [ -n "$content" ]; then
  if printf '%s' "$content" | grep -Eq \
    'sk-[A-Za-z0-9]{20,}|sk-ant-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----'; then
    deny "the content contains what looks like a real API key / private key. Use a \${VAR} reference instead."
  fi
fi

exit 0
