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
# absent <regex> <where> <label> — the pattern must NOT appear.
# The search paths are verified to exist first: grep over a nonexistent directory returns
# non-zero, which would report a vacuous ✓ and turn a renamed directory into a silent no-op.
absent() {
  local d
  for d in $2; do [ -e "$d" ] || { no "$3 — search path does not exist: $d"; return; }; done
  if grep -rqiE "$1" $2 2>/dev/null; then no "$3"; grep -rilE "$1" $2 2>/dev/null | sed 's/^/      /'; else ok "$3"; fi
}

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
# Removing only the IGNORE entry un-ignores the file, so the next `git add -A` COMMITS the retired
# surface. That happened. Assert the file itself is gone, on disk and from the index.
[ -e .claude/active-spec ] && no ".claude/active-spec still exists on disk" || ok ".claude/active-spec is gone from disk"
git ls-files --error-unmatch .claude/active-spec >/dev/null 2>&1 \
  && no ".claude/active-spec is TRACKED — un-ignoring it got it committed" || ok ".claude/active-spec is not tracked"
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

echo "the harness binds its own hooks for BOTH providers (decision K, applied to itself)"
python3 - <<'PY' && ok "both of this repo's bindings resolve to real executables" || no "a binding in this repo is dangling"
import json,subprocess,os
root=subprocess.check_output(["git","rev-parse","--show-toplevel"],text=True).strip()
for f,sub in ((".claude/settings.json","$CLAUDE_PROJECT_DIR"),(".codex/hooks.json",None)):
    d=json.load(open(f))
    for g in (grp for ev in d["hooks"].values() for grp in ev):
        for h in g["hooks"]:
            p=h["command"].replace(sub,root) if sub else \
              h["command"].replace('"$(git rev-parse --show-toplevel)"',root).strip('"')
            assert os.path.isfile(p) and os.access(p,os.X_OK), f"{f}: {p}"
PY
python3 - <<'PY' && ok "protect-secrets' matcher includes apply_patch in this repo too" || no "this repo's Codex matcher would skip apply_patch"
import json,sys
for g in (grp for ev in json.load(open(".codex/hooks.json"))["hooks"].values() for grp in ev):
    for h in g["hooks"]:
        if "protect-secrets" in h["command"]:
            assert "apply_patch" in g.get("matcher",""); sys.exit(0)
sys.exit(1)
PY

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
# Membership in the right ARRAY, not presence in the file: a whole-file grep stays green when an
# entry moves from ONCE to FIXED, which is exactly the change that would clobber a repo's docs.
python3 - <<'PY' && ok "every docs scaffold entry is in ONCE, none in FIXED" || no "a docs entry is in the wrong manifest array"
import re,sys,pathlib
t=pathlib.Path("core/skills/adopt-harness/copy.sh").read_text()
def arr(name):
    m=re.search(rf'^{name}=\((.*?)^\)', t, re.S|re.M)
    return re.findall(r'"([^"]+)"', m.group(1)) if m else []
fixed,once=arr("FIXED"),arr("ONCE")
docs=[e for e in fixed+once if e.startswith("adopt/docs")]
assert docs, "no docs entries in either manifest"
bad=[e for e in fixed if e.startswith("adopt/docs")]
assert not bad, f"clobbering entries in FIXED: {bad}"
for f in ("adopt/docs/INDEX.md","adopt/docs/architecture.md","adopt/docs/glossary.md"):
    assert any(e.startswith(f+":") for e in once), f"{f} not in ONCE"
PY

echo "every superseded document says so in its first ten lines"
unbannered=0
for f in specs/harness-standardization/README.md specs/harness-standardization/0*.md \
         specs/harness-standardization/PRE-IMPLEMENTATION-CONTRACT-AUDIT.md \
         specs/harness-standardization/HIGH-LEVEL-CONTEXT.md; do
  head -10 "$f" | grep -qiE 'SUPERSEDED' || { no "no supersession banner: $f"; unbannered=1; }
done
[ "$unbannered" -eq 0 ] && ok "all superseded epic documents carry a banner in their first ten lines"
head -10 specs/harness-standardization/HARNESS-DEPOT-OPERATIONAL-DESIGN-REVIEW.md \
  | grep -qi 'No longer authoritative' && ok "the design review is marked provenance-only" \
  || no "the design review does not declare its status"

echo "the authority order is stated identically everywhere it appears"
python3 - <<'PY' && ok "every authority statement lists DECISIONS-PENDING → CONTRACT → design review → tasks" \
  || no "an authority statement disagrees with the others"
import pathlib,re
# CONTRACT.md must be matched WITHOUT also matching PRE-IMPLEMENTATION-CONTRACT-AUDIT.md, or a
# document could place CONTRACT after plan/tasks.md and still pass. Anchor on the exact filename.
order=[r'DECISIONS-PENDING\.md', r'(?<!-)\bCONTRACT\.md', r'HARNESS-DEPOT-OPERATIONAL-DESIGN-REVIEW',
       r'tasks\.md']
seen_any=False
for p in pathlib.Path("specs/harness-standardization").rglob("*.md"):
    if "snapshot" in p.parts: continue
    for m in re.finditer(r'\*\*Authority:?\*\*(.{0,400})', p.read_text(), re.S):
        body=m.group(1)
        pos=[]
        for pat in order:
            hit=re.search(pat, body)
            if hit: pos.append(hit.start())
        assert pos==sorted(pos), f"{p}: authority names out of order"
        if len(pos)>=3: seen_any=True
assert seen_any, "no authority statement listed enough names to check"
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
# The whole epic directory is authority or record — contract, decisions, superseded plans, the
# wave reports. None of it is a live surface; all of it legitimately NAMES what was retired.
# Enumerating filenames here was brittle and failed the moment the epic gained a document.
HIST=re.compile(r'^specs/harness-standardization/')
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

echo "T0.15 — every claim maps to a step, every step has an observable"
python3 - <<'PY' && ok "the acceptance scenario is internally complete" || no "the acceptance scenario has a gap"
import pathlib,re,sys
t=pathlib.Path("specs/harness-standardization/ACCEPTANCE-SCENARIO.md").read_text()
claims,walk=t.split("## The walk",1)

# 1. every step defined in the walk has a non-empty observable (last table cell)
steps=set(); problems=[]
for line in walk.splitlines():
    m=re.match(r'\|\s*([A-K]\d+)\s*\|(.*)\|(.*)\|\s*$', line)
    if not m: continue
    step,do,obs=m.group(1),m.group(2).strip(),m.group(3).strip()
    steps.add(step)
    if not do:  problems.append(f"{step}: empty action")
    if not obs: problems.append(f"{step}: NO OBSERVABLE")
assert steps, "no steps parsed"

# 2. every step cited in the claim map exists in the walk (ranges and bare sections expand)
cited=set()
for line in claims.splitlines():
    cells=[c.strip() for c in line.split("|")]
    if len(cells)<4 or not line.startswith("|"): continue
    # Collect ANY bolded token, not just well-formed ones: a citation to a step that does not
    # exist must fail loudly, not be filtered out by the pattern that looks for it.
    for a,b in re.findall(r'\*\*([A-Za-z]+\d*)(?:[–-]([A-Za-z]*\d+))?\*\*', cells[3]):
        if b:
            lo,hi=int(re.sub(r'\D','',a)),int(re.sub(r'\D','',b))
            cited |= {f"{a[0]}{n}" for n in range(lo,hi+1)}
        else:
            cited.add(a)
missing={c for c in cited if not (c in steps or (len(c)==1 and any(s[0]==c for s in steps)))}
problems += [f"claim map cites {c}, which the walk does not define" for c in sorted(missing)]

# 3. no §7 row may have an empty Step cell
for line in claims.splitlines():
    cells=[c.strip() for c in line.split("|")]
    if len(cells)>4 and cells[1]=="§7" and not cells[3]:
        problems.append(f"unmapped §7 claim: {cells[2][:60]}")

# 4. every claim marker CONTRACT §7 raises must be represented in the map. Without this the
#    whole check is asserted against the scenario's own fixture: a new §7 guarantee could land
#    with no row and nothing would notice.
c=pathlib.Path("specs/harness-standardization/CONTRACT.md").read_text()
s7=c.split("## 7. The day-to-day journey",1)[1].split("\n## 8.",1)[0]
markers=[m.group(1).replace("\n"," ") for m in re.finditer(r'^⚠? ?\*\*(.+?)\*\*', s7, re.M|re.S)]
# a marker is represented if the claim table mentions its distinctive words
KEY={"default":"default","T3":"T3","creators":"creators","eager":"eager","lazy":"lazy",
     "orients":"orients","cleanup":"cleanup","sweep":"sweep","Phone":"Phone","order":"order"}
for mk in markers:
    words=[v for k,v in KEY.items() if k.lower() in mk.lower()]
    if not words:
        problems.append(f"CONTRACT §7 marker has no keyword mapping: {mk[:60]}"); continue
    if not any(w.lower() in claims.lower() for w in words):
        problems.append(f"CONTRACT §7 claim unmapped in the scenario: {mk[:60]}")

if problems:
    print("\n".join("      "+p for p in problems), file=sys.stderr); sys.exit(1)
print(f"      {len(steps)} steps, {len(cited)} citations, {len(markers)} §7 markers, all resolved", file=sys.stderr)
PY

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
