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

.PHONY: check setup gate-unconfigured harness-canary $(GATE_STEPS) $(SETUP_STEPS)

# The one command everything points at. Fails fast on the first red step.
check: harness-canary $(GATE_STEPS)
	@echo "✅ quality gate passed — this is what 'done' means"

# Canary for the adapter layout (.agents/ home, .claude/ symlinks). The symlink resolution it
# guards is UNDOCUMENTED Claude behavior (verified 2.1.223) and silently mangled by a clone with
# core.symlinks=false — either failure would load zero skills without a word. No-op in a repo
# that has not adopted the neutral-root layout (no .agents/MANIFEST).
harness-canary:
	@test ! -f .agents/MANIFEST || { \
	  { test -L .claude/skills && test -e .claude/skills; } \
	    || { echo "✗ .claude/skills is not a resolving symlink to .agents/skills"; exit 1; }; \
	  bad=$$(find .claude/agents -maxdepth 1 -type l ! -exec test -e {} \; -print 2>/dev/null); \
	  test -z "$$bad" || { echo "✗ dangling agent symlink(s):"; echo "$$bad" | sed 's/^/    /'; exit 1; }; \
	  ls .agents/hooks/*.sh >/dev/null 2>&1 \
	    || { echo "✗ no hook scripts at .agents/hooks/"; exit 1; }; \
	  for h in $$(grep -ho '\.agents/hooks/[A-Za-z0-9._-]*\.sh' .claude/settings.json .claude/settings.local.json .codex/hooks.json 2>/dev/null | sort -u); do \
	    test -x "$$h" || { echo "✗ a binding names $$h but it is missing or not executable"; exit 1; }; \
	  done; \
	  for h in $$(grep -ho '\.claude/hooks/[A-Za-z0-9._-]*\.sh' .claude/settings.json .claude/settings.local.json .codex/hooks.json 2>/dev/null | sort -u); do \
	    test -e "$$h" || { echo "✗ a binding still points at the old home: $$h (missing)"; exit 1; }; \
	  done; \
	  bad=$$(grep -rIonE '\.workspace/[A-Za-z0-9_.-]+' --exclude-dir=.git --exclude-dir=node_modules \
	          --exclude-dir=.workspace --exclude-dir=dist . 2>/dev/null \
	        | grep -vE ':\.workspace/(MISSION\.md|LOG\.md|history|artifacts)$$'); \
	  test -z "$$bad" || { echo "✗ a live surface names a workspace file the contract does not define:"; \
	    echo "$$bad" | sed 's/^/    /'; \
	    echo "    the contract is .workspace/{MISSION.md,LOG.md,history,artifacts}"; exit 1; }; \
	  echo "→ harness canary: adapters resolve, hooks present, workspace names are contract names"; }

# Run once per fresh clone/worktree before the gate or the app. Idempotent.
setup: $(SETUP_STEPS)
	@echo "✅ setup complete"

gate-unconfigured:
	@echo "⚠  make/gate.mk not found — the quality gate is a NO-OP."
	@echo "   cp make/gate.example-python.mk make/gate.mk  (or -ts), then set GATE_STEPS."

# `work` (spec binding) is deleted — DEC-6: a worktree records its spec in .workspace/MISSION.md's
# `spec:` field, edited like any other line. `install-global` is deleted too: install.sh publishes
# core/ to ~/.agents/, and a second, unguarded pusher is exactly the drift it exists to end.
