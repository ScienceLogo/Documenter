PYTHON ?= python

.PHONY: validate release-check

validate:
	PYTHON=$(PYTHON) ./scripts/validate-local.sh

release-check:
	PYTHON=$(PYTHON) ./scripts/release-check-local.sh
