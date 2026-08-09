#!/usr/bin/env bash
# Repo-content invariants asserted directly from CONTRACT.md (plan/tasks.md T0.12 – T0.14).
#
# The other suites exercise scripts; this one asserts things that are true of the tree itself —
# what a description may not imply, what may not survive a retirement, what may not be said twice.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

pass=0 fail=0
ok() { pass=$((pass+1)); printf '  ✓ %s\n' "$1"; }
no() { fail=$((fail+1)); printf '  ✗ %s\n' "$1"; }
# absent <regex> <where> <label> — the pattern must NOT appear
absent() { if grep -rqiE "$1" $2 2>/dev/null; then no "$3"; grep -rilE "$1" $2 2>/dev/null | sed 's/^/      /'; else ok "$3"; fi; }

AGENTS="core/claude/agents core/codex/agents"

echo "T0.12 — reviewers run only when asked (DECISION E)"
absent 'Trigger after an implementation is' "$AGENTS" "reviewer's self-trigger sentence is gone from both formats"
absent 'Trigger whenever the diff hits a hotspot' "$AGENTS" "reviewer-security's self-trigger sentence is gone from both formats"
# YAML folds a long description across lines, so match against whitespace-normalised text.
for f in core/claude/agents/reviewer.md core/claude/agents/reviewer-security.md \
         core/codex/agents/reviewer.toml core/codex/agents/reviewer-security.toml; do
  tr '\n' ' ' <"$f" | tr -s ' ' | grep -qi 'only when the developer explicitly asks' \
    && ok "$(basename "$f") states it is never invoked automatically" \
    || no "$(basename "$f") does not state that it runs only on request"
done
grep -q '^model: opus$' core/claude/agents/reviewer-security.md \
  && ok "reviewer-security is model: opus" || no "reviewer-security is not opus"
grep -q '^model: sonnet$' core/claude/agents/reviewer.md \
  && ok "reviewer stays model: sonnet" || no "reviewer's model changed unexpectedly"
grep -q 'do not invoke' core/claude/agents/reviewer.md \
  && ok "reviewer names hotspots rather than delegating to reviewer-security" \
  || no "reviewer may still delegate to reviewer-security"

echo "the four agents are one text in two formats (CONTRACT §5)"
python3 - <<'PY' && ok "every Claude .md body is byte-identical to its Codex .toml body" || no "an agent's two formats have drifted"
import re,sys,tomllib,pathlib
for md in sorted(pathlib.Path("core/claude/agents").glob("*.md")):
    toml=pathlib.Path("core/codex/agents")/(md.stem+".toml")
    body=re.sub(r"^---\n.*?\n---\n","",md.read_text(),flags=re.S).strip()
    dev=tomllib.loads(toml.read_text())["developer_instructions"].strip()
    assert body==dev, f"{md.name} != {toml.name}"
PY

echo "open-a-pr owns the LOG.md carry; nothing restates it (CONTRACT §4)"
grep -q 'Decisions' .claude/skills/open-a-pr/pr-description.md \
  && ok "the PR template has a Decisions section" || no "the PR template has no Decisions section"
grep -qi 'LOG.md' .claude/skills/open-a-pr/SKILL.md \
  && ok "open-a-pr instructs the carry" || no "open-a-pr does not mention LOG.md"
grep -qi 'owned by' .claude/commands/ship.md && ! grep -qi 'Carry the settled decisions' .claude/commands/ship.md \
  && ok "ship delegates the carry instead of duplicating it" || no "ship still restates the PR procedure"

echo "T0.13 — the retired surfaces are gone, and nothing dangles"
[ -e .claude/FLOOR.md ] && no ".claude/FLOOR.md still exists" || ok ".claude/FLOOR.md is removed"
absent '@\.claude/FLOOR\.md' "CLAUDE.md adopt core .claude" "no @.claude/FLOOR.md import survives"
grep -qE '^work:' adopt/Makefile && no "the Makefile work target survives" || ok "the Makefile work target is gone"
grep -qE '^install-global:' adopt/Makefile && no "install-global survives" || ok "install-global is retired"
grep -q 'active-spec' .gitignore && no ".gitignore still ignores active-spec" || ok "the active-spec ignore entry is gone"
grep -q '\.workspace' .gitignore && no ".workspace/ is in a repo .gitignore (it must be global-only)" \
  || ok ".workspace/ is not in the repo .gitignore — exclusion is global (CONTRACT §2)"
make -n work >/dev/null 2>&1 && no "make work still resolves" || ok "make work no longer resolves"
make -n check >/dev/null 2>&1 && ok "make check still resolves after the removals" || no "make check broke"
make -n setup >/dev/null 2>&1 && ok "make setup still resolves after the removals" || no "make setup broke"

echo "FLOOR's content reached its assigned homes (DECISION I)"
grep -q '## Definition of done' core/skills/verify-before-done/SKILL.md \
  && ok "Definition of done lives in verify-before-done" || no "Definition of done has no home"
grep -qi 'never claim done on unrun code' CLAUDE.md \
  && ok "the profile still carries 'never claim done on unrun code'" || no "that rule was lost"
grep -qi 'task branch' CLAUDE.md && ok "the profile still carries the task-branch rule" || no "task-branch rule lost"
grep -qi 'Risk hotspots' CLAUDE.md && ok "the profile still carries risk hotspots" || no "risk hotspots lost"
grep -qi 'STARTER_CHARACTER' CLAUDE.md && ok "the profile still carries the skill-marker rule" || no "skill-marker rule lost"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
