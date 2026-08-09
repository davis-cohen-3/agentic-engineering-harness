# The quality gate. `make check` is the single definition of "done".
# Run the SAME target locally, in /ship, and in CI — no drift.
#
# This is the BASE harness file. Do NOT put repo-specific commands here.
# A repo enumerates its REAL checks in make/gate.mk (Slot 2 of OVERLAY-CONTRACT):
#   cp make/gate.example-python.mk make/gate.mk   # or -ts, then edit
# Onboarding = fill the overlay, not rewrite this file.

# Pull in the repo's gate + setup overlay if it exists. The leading `-` means
# "no error if missing" so a bare drop-in still runs (just no-op green).
-include make/gate.mk

# The named checks the gate runs, in order. The overlay sets GATE_STEPS to its
# real checks (e.g. `format lint typecheck test build arch-lint`). With no
# overlay present, fall back to a loud no-op so a fresh drop-in is honestly green
# but tells you it is unconfigured.
GATE_STEPS ?= gate-unconfigured

# Bootstrap (Slot 1): install deps + provision env so the gate and the app work
# in a fresh worktree or sandbox clone. The overlay sets SETUP_STEPS; default none.
SETUP_STEPS ?=

.PHONY: check setup gate-unconfigured $(GATE_STEPS) $(SETUP_STEPS)

# The one command everything points at. Fails fast on the first red step.
check: $(GATE_STEPS)
	@echo "✅ quality gate passed — this is what 'done' means"

# Run once per fresh clone/worktree before the gate or the app. Idempotent.
setup: $(SETUP_STEPS)
	@echo "✅ setup complete"

gate-unconfigured:
	@echo "⚠  make/gate.mk not found — the quality gate is a NO-OP."
	@echo "   cp make/gate.example-python.mk make/gate.mk  (or -ts), then set GATE_STEPS."

# `work` (spec binding) is deleted — DEC-6: a worktree records its spec in .workspace/MISSION.md's
# `spec:` field, edited like any other line. `install-global` is deleted too: install.sh publishes
# core/ to ~/.agents/, and a second, unguarded pusher is exactly the drift it exists to end.
