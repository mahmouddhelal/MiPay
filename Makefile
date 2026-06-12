.PHONY: up down logs setup migrate test clean shell-api shell-db

up:
	docker compose up --build -d

down:
	docker compose down

logs:
	docker compose logs -f api

setup: up
	@echo "Waiting for services..."
	@sleep 8
	@bash scripts/setup.sh

migrate:
	docker compose exec api alembic upgrade head

test:
	docker compose exec api pytest -v

clean:
	docker compose down -v

shell-api:
	docker compose exec api bash

shell-db:
	docker compose exec postgres psql -U mipay mipay
