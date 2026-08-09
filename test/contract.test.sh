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
  && ok "Definition of done → verify-before-done" || no "Definition of done has no home"
grep -qi 'never claim done on unrun code' AGENTS.md \
  && ok "the profile carries 'never claim done on unrun code'" || no "that rule was lost"
grep -qi 'task branch' AGENTS.md && ok "the profile carries the task-branch rule" || no "task-branch rule lost"
grep -qi 'hotspots' AGENTS.md && ok "the profile carries risk hotspots" || no "risk hotspots lost"
grep -qi 'One run builds one task' adopt/specs/README.md \
  && ok "two-modes / one-run-one-task → specs/README.md" || no "the build-mode rules have no home"
grep -qiE '^\| \*\*T0\*\*' adopt/specs/README.md \
  && ok "the T0–T3 tier table → specs/README.md" || no "the tier definitions have no home"
miss=0; for s in core/skills/*/SKILL.md; do grep -q 'STARTER_CHARACTER' "$s" || { miss=1; echo "      $s"; }; done
[ "$miss" = 0 ] && ok "every core skill declares its own STARTER_CHARACTER" || no "a core skill has no marker"

echo "T0.14 — one documentation namespace, one profile (DECISION L)"
[ -f AGENTS.md ] && ok "the harness has its own AGENTS.md" || no "AGENTS.md is missing"
grep -q '^@AGENTS.md$' CLAUDE.md && ok "CLAUDE.md imports AGENTS.md" || no "CLAUDE.md does not import AGENTS.md"
[ "$(wc -l <CLAUDE.md)" -lt 15 ] && ok "CLAUDE.md is a stub, not a second profile" \
  || no "CLAUDE.md has grown into a second profile ($(wc -l <CLAUDE.md) lines)"
[ -d agent_docs ] && no "agent_docs/ still exists" || ok "agent_docs/ is retired"
for f in docs/INDEX.md adopt/docs/INDEX.md adopt/docs/architecture.md adopt/docs/glossary.md \
         adopt/docs/adrs/README.md adopt/docs/adrs/0000-template.md; do
  [ -f "$f" ] && ok "$f exists" || no "$f is missing"
done
ls docs/*.md 2>/dev/null | grep -qE 'HIGH-LEVEL-CONTEXT|DESIGN-REVIEW|RESEARCH-20|REVIEW-20' \
  && no "a planning/research artifact is still in docs/" || ok "docs/ holds no planning artifacts"
grep -q 'adopt/docs/INDEX.md:docs/INDEX.md' core/skills/adopt-harness/copy.sh \
  && ok "the docs scaffold travels (write-only-when-absent)" || no "the docs scaffold does not travel"
grep -q '"adopt/docs:docs"' core/skills/adopt-harness/copy.sh \
  && no "adopt/docs is copied unconditionally — it would clobber a repo's filled-in docs" \
  || ok "adopt/docs is not in the unconditional manifest"

echo "every superseded document says so in its first ten lines"
for f in specs/harness-standardization/README.md specs/harness-standardization/0*.md \
         specs/harness-standardization/PRE-IMPLEMENTATION-CONTRACT-AUDIT.md \
         specs/harness-standardization/HIGH-LEVEL-CONTEXT.md; do
  head -10 "$f" | grep -qiE 'SUPERSEDED' || { no "no supersession banner: $f"; continue; }
done
ok "all superseded epic documents carry a banner in their first ten lines"
head -10 specs/harness-standardization/HARNESS-DEPOT-OPERATIONAL-DESIGN-REVIEW.md \
  | grep -qi 'No longer authoritative' && ok "the design review is marked provenance-only" \
  || no "the design review does not declare its status"

echo "the authority order is stated identically everywhere it appears"
python3 - <<'PY' && ok "every authority statement lists DECISIONS-PENDING → CONTRACT → design review → tasks" \
  || no "an authority statement disagrees with the others"
import pathlib,re
# Unambiguous tokens only: a bare "CONTRACT" also matches PRE-IMPLEMENTATION-CONTRACT-AUDIT.
order=["DECISIONS-PENDING","HARNESS-DEPOT-OPERATIONAL-DESIGN-REVIEW","tasks.md"]
seen_any=False
for p in pathlib.Path("specs/harness-standardization").rglob("*.md"):
    if "snapshot" in p.parts: continue
    for m in re.finditer(r'\*\*Authority:?\*\*(.{0,400})', p.read_text(), re.S):
        body=m.group(1)
        pos=[body.index(n) for n in order if n in body]
        assert pos==sorted(pos), f"{p}: authority names out of order"
        if len(pos)>=2: seen_any=True
assert seen_any, "no authority statement found to check"
PY

echo "no dangling markdown links"
python3 - <<'PY' && ok "every relative markdown link resolves" || no "a markdown link is dangling"
import pathlib,re
skip={"./src/ordering/CONTEXT.md","./src/billing/CONTEXT.md","./src/fulfillment/CONTEXT.md","link"}
bad=[]
for p in pathlib.Path(".").rglob("*.md"):
    if ".git" in p.parts or "snapshot" in p.parts: continue
    for m in re.finditer(r'\]\(([^)#][^)]*)\)', p.read_text()):
        t=m.group(1).split("#")[0]
        if not t or t.startswith(("http","mailto:")) or t in skip: continue
        if not (p.parent/t).exists(): bad.append(f"{p} -> {t}")
assert not bad, bad
PY

echo "retired conventions survive only in historical documents"
python3 - <<'PY' && ok "no live surface references a retired convention" || no "a retired convention is still live"
import pathlib,re
HIST=re.compile(r'specs/harness-standardization/(0[1-8]|README|PRE-IMPL|CONTRACT|DECISIONS|WAVE-0|plan/|snapshot/|HIGH-LEVEL|HARNESS-DEPOT|research/)')
RETIRED=re.compile(r'\.claude/active-spec|make work SPEC|thoughts\.md|\.sessions/|\.context/<|agent_docs')
# Allowed: files whose whole job is to DESCRIBE a retirement — assert it is gone, refuse to copy
# it, or tabulate what replaced it. A new *instruction* to use a retired surface still fails.
ALLOW=("test/","packs/","adopt/Makefile",
       "adopt/hooks/spec-session-orient.sh",          # header notes what the old version did
       "adopt/specs/README.md",                       # the "Retired outright" table
       "core/skills/adopt-harness/SKILL.md")          # "confirm no retired companion travelled"
bad=[]
for p in pathlib.Path(".").rglob("*"):
    if not p.is_file() or ".git" in p.parts: continue
    if HIST.search(str(p)) or any(str(p).startswith(a) for a in ALLOW): continue
    if p.suffix not in (".md",".sh",".json",".mk",".toml") and p.name!="Makefile": continue
    try: t=p.read_text()
    except Exception: continue
    for n,line in enumerate(t.splitlines(),1):
        if RETIRED.search(line): bad.append(f"{p}:{n}: {line.strip()[:90]}")
assert not bad, "\n".join(bad)
PY

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
