FROM python:3.12-slim AS docs-builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY pyproject.toml PLAN.md README.md ./
COPY conf ./conf
COPY docs ./docs
COPY src ./src

RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir ".[dev]" \
    && python -m mkdocs build -f conf/mkdocs.yml

FROM python:3.12-slim

LABEL org.opencontainers.image.source=https://github.com/matoanbach/lockedin-backend

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY pyproject.toml PLAN.md README.md ./
COPY conf ./conf
COPY src ./src
COPY --from=docs-builder /app/.artifacts ./.artifacts

RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir .

EXPOSE 8000

CMD ["gunicorn", "-c", "conf/gunicorn.conf.py", "lockedin_backend.app.main:app"]
