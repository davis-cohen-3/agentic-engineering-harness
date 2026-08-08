# The harness repo consumes its own adopt/ payload rather than duplicating it.
# adopt/Makefile -includes make/gate.mk, resolved from the CWD make runs in.
include adopt/Makefile
