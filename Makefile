.PHONY: test test-lua test-static verify-upstream test-integration

PYTHON ?= python3
LUA ?= luajit

# Standalone: no Gen1Recomp checkout required.
test: test-lua test-static

test-lua:
	$(LUA) tests/run.lua

test-static:
	$(PYTHON) -m unittest tests.test_manifest tests.test_repository_boundaries tests.test_verify_upstream -v

verify-upstream:
	$(PYTHON) tools/verify_upstream.py

# Integration: requires GEN1RECOMP_ROOT pointing at the pinned v0.2.74 checkout
# and an imported Gen 1 cache for modkit's imported base.
test-integration: verify-upstream
	cd "$(GEN1RECOMP_ROOT)" && $(PYTHON) tools/modkit.py validate "$(CURDIR)" --base imported
