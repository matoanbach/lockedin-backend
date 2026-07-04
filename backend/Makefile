.PHONY: install-venv init-env run build-docs docs-build docs-serve test test-postgres clean

PROJECT_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
PY ?= python
PYVENV ?= .venv
VENV := $(PROJECT_DIR)/$(PYVENV)
ifeq ($(OS),Windows_NT)
VENV_PY := $(VENV)/Scripts/python.exe
else
VENV_PY := $(VENV)/bin/python
endif
HOST ?= 127.0.0.1
PORT ?= 8000

ensure-venv:
	@if [ ! -f "$(VENV_PY)" ] && [ ! -f "$(VENV_PY).exe" ]; then \
		"$(PY)" -m venv "$(VENV)"; \
		"$(VENV_PY)" -m pip install --upgrade pip; \
		"$(VENV_PY)" -m pip install -e ".[dev]"; \
	fi

install-venv:
	"$(PY)" -m venv "$(VENV)"
	"$(VENV_PY)" -m pip install --upgrade pip
	"$(VENV_PY)" -m pip install -e ".[dev]"

init-env:
	"$(VENV_PY)" scripts/init_env.py

run: ensure-venv
	cd "$(PROJECT_DIR)" && "$(VENV_PY)" -m uvicorn lockedin_backend.app.main:app --host $(HOST) --port $(PORT)

build-docs: ensure-venv
	cd "$(PROJECT_DIR)" && "$(VENV_PY)" -m mkdocs build -f "$(PROJECT_DIR)/conf/mkdocs.yml"

docs-build: build-docs

docs-serve: ensure-venv
	cd "$(PROJECT_DIR)" && "$(VENV_PY)" -m mkdocs serve -f "$(PROJECT_DIR)/conf/mkdocs.yml" --dev-addr $(HOST):9001

test: ensure-venv
	cd "$(PROJECT_DIR)" && "$(VENV_PY)" -m pytest

test-postgres: ensure-venv
	cd "$(PROJECT_DIR)" && TEST_DATABASE_URL="$(or $(TEST_DATABASE_URL),postgresql+psycopg://postgres:postgres@localhost:5433/lockedin)" "$(VENV_PY)" -m pytest tests/test_postgres_integration.py

clean:
	"$(PY)" -c "import pathlib, shutil; p=pathlib.Path(r'$(PROJECT_DIR)'); [(shutil.rmtree(p/d, ignore_errors=True)) for d in ['.pytest_cache','.mypy_cache','.ruff_cache','build','dist','$(PYVENV)']]; [(shutil.rmtree(x, ignore_errors=True)) for x in p.glob('*.egg-info')]; (p/'lockdin.db').unlink(missing_ok=True)"
