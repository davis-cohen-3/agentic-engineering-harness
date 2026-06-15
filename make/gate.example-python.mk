# Gate overlay (Slot 2) — Python / FastAPI example. Copy to make/gate.mk and edit.
# Validated shape from melting (Python/FastAPI + React). Keep `check` composed in
# the base Makefile; this file only enumerates the named checks + how to run each.

# Ordered named checks. Put cheap/fast first, the expensive `test` near the end.
# Add your repo's CUSTOM checks here too (melting's gate is ~half architecture
# linters — the base can't discover those, so the overlay MUST list them).
GATE_STEPS  = format lint typecheck test
# e.g. add a custom architecture linter:  GATE_STEPS += arch-lint

# Bootstrap so the gate works in a fresh worktree/sandbox (Slot 1).
SETUP_STEPS = deps

deps:
	uv sync                       # or: pip install -e ".[dev]"

format:
	ruff format --check .

lint:
	ruff check .

typecheck:
	mypy .

test:
	pytest -q                     # the EXPENSIVE check — runs ONCE here

# Example custom check (delete if unused):
# arch-lint:
# 	python tools/check_layers.py
