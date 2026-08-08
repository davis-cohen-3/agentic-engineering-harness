# Gate overlay (Slot 2) — ACTIVE for THIS repo (agentic-coding-harness).
#
# agentic-coding-harness is a HARNESS BASE, not an app, so its "gate" validates the harness
# itself: config is valid JSON and hooks are executable. A real repo DELETES this
# and copies make/gate.example-python.mk or -ts.mk in its place.

GATE_STEPS = validate-json validate-hooks test-install

validate-json:
	@python3 -c "import json,sys; [json.load(open(f)) for f in ('.claude/settings.json','.mcp.json')]; print('→ json valid')"

validate-hooks:
	@n=0; for h in core/hooks/*.sh; do \
		test -e "$$h" || { echo "✗ no hooks found at core/hooks/*.sh"; exit 1; }; \
		test -x "$$h" || { echo "✗ not executable: $$h (chmod +x it)"; exit 1; }; \
		n=$$((n+1)); \
	done; \
	echo "→ $$n hooks executable"

# install.sh writes the machine tree; it is tested against a sandbox $HOME, never the real one.
test-install:
	@./test/install.test.sh >/dev/null 2>&1 && echo "→ install.sh acceptance passed" \
	  || { ./test/install.test.sh; exit 1; }
