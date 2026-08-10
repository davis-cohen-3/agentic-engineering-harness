# Personal preferences (Davis)

Cross-repo defaults for loose work. Suppressed inside any project that owns its own `.claude/` —
there, the project's CLAUDE.md/FLOOR governs instead.

## Working style
- Be concise and direct. Lead with the answer; keep preamble and recap minimal.
- When a decision is genuinely mine to make, ask — show the list first, then ask one at a time.
- No shortcuts and no silent direction changes; flag a course change with ❓ before taking it.
- Match the surrounding code's structure and idiom. Prefer minimal comments — explain the
  non-obvious *why*, never the *what*.

## Engineering defaults
- Work on a task branch, never the default branch. Ship via PR; commit/push only when asked.
- Don't claim something is done on unrun code — actually run the change and report what I saw,
  with the output. If a step was skipped or failed, say so plainly.
- Secrets never go in committed files or plaintext config. Use env vars; personal secrets live
  in `~/.claude/secrets.env` (chmod 600, sourced from the shell) and are referenced as `${VAR}`.

## Tooling
- Shell: zsh on macOS. Prefer `gh` for GitHub operations.
- When I ask you to run an interactive command yourself, I'll prefix it with `!` in the prompt.
