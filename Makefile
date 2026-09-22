.PHONY: test test-integration verify-upstream

PYTHON ?= python3

test:
	$(PYTHON) -m unittest discover -s tests -v

verify-upstream:
	$(PYTHON) tools/verify_upstream.py

test-integration: verify-upstream
	$(PYTHON) -m unittest discover -s integration_tests -v
