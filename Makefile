.PHONY: test test-lua test-static verify-upstream test-integration test-imported-matrix test-fixture package clean-package

PYTHON ?= python3
LUA ?= luajit
ZIP ?= zip
ENGINE_TARGET ?= v0.2.74
ENGINE_BASE ?= imported
VERSION = $(shell $(PYTHON) -c 'import json; print(json.load(open("manifest.json"))["version"])')
PACKAGE = dist/gen1recomp_dscrete_items-$(VERSION).zip

# Standalone: no Gen1Recomp checkout required.
test: test-lua test-static

test-lua:
	$(LUA) tests/run.lua

test-static:
	$(PYTHON) -m unittest tests.test_manifest tests.test_repository_boundaries tests.test_verify_upstream tests.test_fixture_gate tests.test_imported_matrix -v

verify-upstream:
	$(PYTHON) tools/verify_upstream.py --target $(ENGINE_TARGET)

# Full integration uses a selected, SHA-verified engine checkout and imported base.
test-integration: verify-upstream
	cd "$(GEN1RECOMP_ROOT)" && $(PYTHON) tools/modkit.py validate "$(CURDIR)" --base $(ENGINE_BASE)

# Exact-revision, real imported-data compatibility matrix. Requires three
# legitimate local engine checkouts each with its own imported Gen 1 cache.
test-imported-matrix:
	$(PYTHON) tools/imported_matrix.py

# ROM-free loader check for CI; fixture data is not an imported game cache.
test-fixture: verify-upstream
	$(PYTHON) tools/fixture_gate.py "$(GEN1RECOMP_ROOT)" "$(CURDIR)"

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
