.PHONY: install-venv init-env run test test-postgres clean

PROJECT_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
PY ?= python3
PYVENV ?= .venv
VENV := $(PROJECT_DIR)/$(PYVENV)
VENV_PY := $(VENV)/bin/python
HOST ?= 127.0.0.1
PORT ?= 8000

install-venv:
	"$(PY)" -m venv "$(VENV)"
	"$(VENV_PY)" -m pip install --upgrade pip
	"$(VENV_PY)" -m pip install -e ".[dev]"

init-env:
	"$(VENV_PY)" scripts/init_env.py

run:
	cd "$(PROJECT_DIR)" && "$(VENV_PY)" -m uvicorn lockedin_backend.app.main:app --host $(HOST) --port $(PORT)

test:
	cd "$(PROJECT_DIR)" && "$(VENV_PY)" -m pytest

test-postgres:
	cd "$(PROJECT_DIR)" && TEST_DATABASE_URL="$(or $(TEST_DATABASE_URL),postgresql+psycopg://postgres:postgres@localhost:5433/lockedin)" "$(VENV_PY)" -m pytest tests/test_postgres_integration.py

clean:
	"$(PY)" -c "import pathlib, shutil; p=pathlib.Path(r'$(PROJECT_DIR)'); [(shutil.rmtree(p/d, ignore_errors=True)) for d in ['.pytest_cache','.mypy_cache','.ruff_cache','build','dist','$(PYVENV)']]; [(shutil.rmtree(x, ignore_errors=True)) for x in p.glob('*.egg-info')]; (p/'lockdin.db').unlink(missing_ok=True)"
