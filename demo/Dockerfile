# Demo pipeline image: Python (uv) + Node in one container.
# Runs ingestion -> dbt -> Evidence static build on a daily schedule.
FROM node:20-bookworm-slim

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates rsync tzdata && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Python deps (uv downloads its own Python per .python-version/pyproject)
COPY pyproject.toml uv.lock ./
# dbt-core 1.x does not support Python 3.14 yet — pin 3.12
RUN uv python install 3.12 && uv sync --frozen --no-dev --python 3.12

# Node deps for Evidence
COPY bi/workspace/package.json bi/workspace/package-lock.json ./bi/workspace/
RUN cd bi/workspace && npm ci

# Project code
COPY src ./src
COPY dbt_warehouse ./dbt_warehouse
COPY bi/workspace ./bi/workspace

COPY demo/run_pipeline.sh demo/entrypoint.sh /app/demo/
RUN sed -i 's/\r$//' /app/demo/*.sh && chmod +x /app/demo/*.sh

ENV TZ=Europe/Helsinki \
    NODE_OPTIONS=--max-old-space-size=4096 \
    BACKFILL_DAYS=7 \
    UPDATE_HOUR=7

CMD ["bash", "/app/demo/entrypoint.sh"]
