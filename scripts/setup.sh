#!/usr/bin/env bash
set -euo pipefail

echo "==> Pulling Ollama model (qwen2.5:7b-instruct)..."
docker compose exec ollama ollama pull qwen2.5:7b-instruct

echo "==> Running database migrations..."
docker compose exec api alembic upgrade head

echo "==> Done. MiPay API is ready at http://localhost:8000"
echo "    Health check: curl http://localhost:8000/api/v1/health"
