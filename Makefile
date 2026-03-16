.PHONY: test-py test-r-xcms test-r-stats test-all docker-build docker-up verify-parity setup lint

# Python tests
test-py:
	uv run pytest packages/common/metabodata/tests/ -v

# R tests
test-r-xcms:
	cd packages/engines/xcms-worker && \
	Rscript -e "testthat::test_dir('tests/testthat/')"

test-r-stats:
	cd packages/engines/stats-worker && \
	Rscript -e "testthat::test_dir('tests/testthat/')"

# All tests
test-all: test-py test-r-xcms test-r-stats

# Lint
lint:
	uv run ruff check packages/common/
	uv run mypy packages/common/metabodata/

# Docker
docker-build:
	docker compose build

docker-up:
	docker compose up -d

docker-down:
	docker compose down

# Verification
verify-parity:
	Rscript scripts/verify_parity.R

# Dev setup
setup:
	uv sync --all-extras
	@echo "Python dependencies installed."
	@echo "For R dependencies, run renv::restore() in each engine directory."
