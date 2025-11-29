IMAGE_NAME = newsela-tools

.PHONY: lint build docker-lint clean_venv fix docker_fix install .venv

help:
	@echo "Usage: make [target]"
	@echo "Targets available:"
	@echo "--------------------------------------------------------"
	@echo "  make help           - Show this help message."
	@echo "  make install        - Install Python dependencies into .venv."
	@echo "  make lint           - Run SQL linter locally (Check style)."
	@echo "  make fix            - Auto-fix SQL style violations (Local)."
	@echo "  make docker-lint    - Run linter in the isolated Docker environment."
	@echo "  make docker-fix     - Auto-fix SQL via Docker, persisting changes."
	@echo "  make docker-clean   - Remove the local Docker tooling image."
	@echo "  make venv-clean     - Remove the local Python virtual environment."
	@echo "--------------------------------------------------------"

venv:
	python3 -m venv .venv

install:
	./.venv/bin/pip install --upgrade -r requirements.txt

lint:
	./.venv/bin/sqlfluff lint src/queries/ --dialect bigquery

fix:
	./.venv/bin/sqlfluff fix src/queries/ --dialect bigquery

build:
	docker build -t newsela-tools .

docker-lint:
	docker run --rm -v $(PWD):/app newsela-tools
	
docker-fix:
	docker run --rm -v $(PWD):/app newsela-tools sqlfluff fix src/queries/ --dialect bigquery --force

docker-clean:
	-docker rmi -f $(IMAGE_NAME) || true

venv-clean:
	rm -rf .venv $(VENV_STAMP)