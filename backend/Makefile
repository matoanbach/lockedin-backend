.PHONY: install-venv init-env run test migrate revision clean

PROJECT_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
PY ?= python3
PYVENV ?= .venv
VENV := $(PROJECT_DIR)/$(PYVENV)
VENV_PY := $(VENV)/bin/python
HOST ?= 127.0.0.1
PORT ?= 8000
MESSAGE ?= update schema

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

migrate:
	cd "$(PROJECT_DIR)" && "$(VENV_PY)" -m alembic upgrade head

revision:
	cd "$(PROJECT_DIR)" && "$(VENV_PY)" -m alembic revision --autogenerate -m "$(MESSAGE)"

clean:
	"$(PY)" -c "import pathlib, shutil; p=pathlib.Path(r'$(PROJECT_DIR)'); [(shutil.rmtree(p/d, ignore_errors=True)) for d in ['.pytest_cache','.mypy_cache','.ruff_cache','build','dist','$(PYVENV)']]; [(shutil.rmtree(x, ignore_errors=True)) for x in p.glob('*.egg-info')]; (p/'lockdin.db').unlink(missing_ok=True)"
