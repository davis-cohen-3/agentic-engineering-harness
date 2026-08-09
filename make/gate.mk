# Gate overlay (Slot 2) — ACTIVE for THIS repo (agentic-coding-harness).
#
# agentic-coding-harness is a HARNESS BASE, not an app, so its "gate" validates the harness
# itself: config is valid JSON and hooks are executable. A real repo DELETES this
# and copies make/gate.example-python.mk or -ts.mk in its place.

GATE_STEPS = validate-json validate-hooks test-install test-adopt test-workspace test-hooks

validate-json:
	@python3 -c "import json,sys; [json.load(open(f)) for f in ('.claude/settings.json','.mcp.json')]; print('→ json valid')"

validate-hooks:
	@n=0; for h in core/hooks/*.sh adopt/hooks/*.sh; do \
		test -e "$$h" || { echo "✗ no hooks found at $$h"; exit 1; }; \
		test -x "$$h" || { echo "✗ not executable: $$h (chmod +x it)"; exit 1; }; \
		n=$$((n+1)); \
	done; \
	echo "→ $$n hooks executable"

# install.sh writes the machine tree; it is tested against a sandbox $HOME, never the real one.
test-install:
	@./test/install.test.sh >/dev/null 2>&1 && echo "→ install.sh acceptance passed" \
	  || { ./test/install.test.sh; exit 1; }

# copy.sh adopts a real disposable repo in a temp dir; nothing outside it is touched.
test-adopt:
	@./test/adopt.test.sh >/dev/null 2>&1 && echo "→ adopt acceptance passed" \
	  || { ./test/adopt.test.sh; exit 1; }

# wt cuts real worktrees, so this test pins XDG_CONFIG_HOME and cwd into a sandbox. It once
# resolved the real registry and created worktrees in a real project; that must not recur.
test-workspace:
	@./test/workspace.test.sh >/dev/null 2>&1 && echo "→ workspace/wt acceptance passed" \
	  || { ./test/workspace.test.sh; exit 1; }

# Every hook against BOTH providers' payload shapes, from a disposable adopted repo.
test-hooks:
	@./test/hooks.test.sh >/dev/null 2>&1 && echo "→ hook parity acceptance passed" \
	  || { ./test/hooks.test.sh; exit 1; }
