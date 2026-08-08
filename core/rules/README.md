# Global rules — ~/.claude/rules/

These files are injected into a session by the `inject-global-rules.sh` SessionStart hook **only
when the session is NOT inside a project** that owns its own `.claude/` or `CLAUDE.md`. Inside such
a project (e.g. anything under a harness-adopted repo), they are fully suppressed — zero token
cost — and the project's own conventions govern.

So these are conventions for **loose / ad-hoc work**: scratch scripts, one-offs, dotfiles, and
repos that haven't adopted a harness. The hook concatenates every `*.md` here (except this
README is included too — keep it short; or rename it out of the way if that ever matters).

To add a rule: drop a `<topic>.md` file here. To disable all global rules: remove the
`SessionStart` hook entry from `~/.claude/settings.json`, or empty this directory.
