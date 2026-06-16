# Gate overlay (Slot 2) — ACTIVE for THIS repo (agentic-coding-harness).
#
# agentic-coding-harness is a HARNESS BASE, not an app, so its "gate" validates the harness
# itself: config is valid JSON and hooks are executable. A real repo DELETES this
# and copies make/gate.example-python.mk or -ts.mk in its place.

GATE_STEPS = validate-json validate-hooks

validate-json:
	@python3 -c "import json,sys; [json.load(open(f)) for f in ('.claude/settings.json','.mcp.json')]; print('→ json valid')"

validate-hooks:
	@for h in .claude/hooks/*.sh; do \
		test -x "$$h" || { echo "✗ not executable: $$h (chmod +x it)"; exit 1; }; \
	done; \
	echo "→ hooks executable"
