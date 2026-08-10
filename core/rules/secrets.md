# Rule: keep secrets out of files

- Never write API keys, tokens, passwords, or connection strings into a file — not into scripts,
  configs, notebooks, or `.env` files that might get committed.
- Personal secrets live in `~/.claude/secrets.env` (chmod 600, sourced from `~/.zshrc`). Reference
  them via environment variables (`${VAR}`), never by pasting the value.
- If I ask you to put a secret somewhere insecure, push back and propose the env-var path instead.
- If a secret has been exposed (printed, committed, pasted into a chat), say so and recommend
  rotating it — don't just move it.
