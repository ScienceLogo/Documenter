PYTHON ?= python
RACO ?= raco

.PHONY: test validate release-check

test:
	PYTHONPATH=src $(PYTHON) -m unittest discover -s tests/python -v
	$(RACO) test tests/racket

validate:
	PYTHON=$(PYTHON) RACO=$(RACO) ./scripts/validate-local.sh

release-check:
	PYTHON=$(PYTHON) ./scripts/release-check-local.sh
