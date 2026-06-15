# Gate overlay (Slot 2) — TypeScript monorepo example. Copy to make/gate.mk and edit.
# Validated shape from smoke-screen (TS npm-workspace monorepo). Keep `check`
# composed in the base Makefile; this file only enumerates the named checks.

# Ordered named checks. In a monorepo, `build` often must run BEFORE typecheck
# (generated types / project refs) — encode that ordering in the list order.
GATE_STEPS  = format lint build typecheck test

# Bootstrap so the gate works in a fresh worktree/sandbox (Slot 1).
SETUP_STEPS = deps

deps:
	npm ci

format:
	npx prettier --check .

lint:
	npx eslint .

build:
	npm run build                 # build first if typecheck needs generated types

typecheck:
	npx tsc --noEmit

test:
	npx vitest run                # the EXPENSIVE check — runs ONCE here
