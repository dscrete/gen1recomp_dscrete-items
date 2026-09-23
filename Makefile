.PHONY: test test-lua test-static verify-upstream test-integration package clean-package

PYTHON ?= python3
LUA ?= luajit
ZIP ?= zip
VERSION = $(shell $(PYTHON) -c 'import json; print(json.load(open("manifest.json"))["version"])')
PACKAGE = dist/gen1recomp_dscrete_items-$(VERSION).zip

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

# Build the exact ZIP shape preferred by Gen1Recomp's GitHub mod updater:
# <manifest id>-<manifest version>.zip, with manifest.json beside main.lua at
# archive root and no repository development/test files.
package: clean-package
	mkdir -p dist/package
	cp manifest.json main.lua dist/package/
	cp -R lib dist/package/
	cd dist/package && $(ZIP) -qr ../gen1recomp_dscrete_items-$(VERSION).zip .
	test -s $(PACKAGE)

clean-package:
	rm -rf dist/package dist/gen1recomp_dscrete_items-*.zip
