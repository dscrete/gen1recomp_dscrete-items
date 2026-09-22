.PHONY: test test-lua test-static verify-upstream test-integration package clean-package

PYTHON ?= python3
LUA ?= luajit
ZIP ?= zip

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

# Build a minimal, directly installable Gen1Recomp mod archive. The archive
# contains the mod at its root (manifest.json beside main.lua), not the repo's
# development/test files.
package: clean-package
	mkdir -p dist/package
	cp manifest.json main.lua dist/package/
	cp -R lib dist/package/
	cd dist/package && $(ZIP) -qr ../dscrete-items-dev.zip .
	test -s dist/dscrete-items-dev.zip

clean-package:
	rm -rf dist/package dist/dscrete-items-dev.zip
