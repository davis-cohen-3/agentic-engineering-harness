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

.PHONY: check setup work install-global gate-unconfigured $(GATE_STEPS) $(SETUP_STEPS)

# The one command everything points at. Fails fast on the first red step.
check: $(GATE_STEPS)
	@echo "✅ quality gate passed — this is what 'done' means"

# Run once per fresh clone/worktree before the gate or the app. Idempotent.
setup: $(SETUP_STEPS)
	@echo "✅ setup complete"

gate-unconfigured:
	@echo "⚠  make/gate.mk not found — the quality gate is a NO-OP."
	@echo "   cp make/gate.example-python.mk make/gate.mk  (or -ts), then set GATE_STEPS."

# Bind THIS worktree to the spec it executes: `make work SPEC=specs/<slug>.md`.
# Writes the gitignored .claude/active-spec pointer the SessionStart hook reads, so every
# resumed/post-compaction session re-anchors without re-supplying the path. This is the eager,
# explicit bind; the hook self-binds from the branch name when this wasn't run.
work:
	@spec="$${SPEC}"; \
	  test -n "$$spec" || { echo "usage: make work SPEC=specs/<slug>.md"; exit 2; }; \
	  case "$$spec" in specs/*) ;; *) echo "✗ SPEC must be a path under specs/ (got: $$spec)"; exit 2;; esac; \
	  case "$$spec" in *..*|*[!a-zA-Z0-9/_.-]*) echo "✗ SPEC has '..' or invalid characters: $$spec"; exit 2;; esac; \
	  test -e "$$spec" || { echo "✗ no such spec: $$spec"; exit 2; }; \
	  mkdir -p .claude && printf '%s\n' "$$spec" > .claude/active-spec; \
	  echo "→ bound this worktree to $$spec  (.claude/active-spec)"

# Sync harness→global config (nothing else does, so they drift). ONLY skills/agents/commands: rules
# and hooks are split-purpose (harness ships project-scoped versions; global has your personal/wired
# ones), so a blanket push pollutes global. Guarded to the harness so an adopted repo can't push its
# stale .claude/ over global. Additive; `DELETE=--delete` for a strict mirror.
CLAUDE_HOME ?= $(if $(CLAUDE_CONFIG_DIR),$(CLAUDE_CONFIG_DIR),$(HOME)/.claude)
DELETE ?=
install-global:
	@test -f CLAUDE.template.md || { echo "✗ install-global runs only from the harness repo (no CLAUDE.template.md here)"; exit 2; }
	@test -d "$(CLAUDE_HOME)" || { echo "✗ no Claude config dir at $(CLAUDE_HOME) — set CLAUDE_CONFIG_DIR"; exit 2; }
	@command -v rsync >/dev/null || { echo "✗ rsync not found"; exit 2; }
	@for d in skills agents commands; do \
	  if [ -d ".claude/$$d" ]; then \
	    echo "  → $$d/"; \
	    rsync -a --itemize-changes $(DELETE) ".claude/$$d/" "$(CLAUDE_HOME)/$$d/"; \
	  fi; \
	done
	@echo "✅ harness .claude/{skills,agents,commands} → $(CLAUDE_HOME)"
