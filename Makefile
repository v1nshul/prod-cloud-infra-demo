.PHONY: help test lint format docker-build docker-push deploy-staging deploy-prod terraform-init terraform-plan terraform-apply terraform-destroy

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

test: ## Run tests
	pytest tests/ -v --cov=app --cov-report=term-missing

lint: ## Run linter
	ruff check app/ tests/

format: ## Format code
	ruff format app/ tests/

docker-build: ## Build Docker image
	docker build -t ghcr.io/v1nshul/prod-cloud-infra-demo:latest .

docker-push: ## Push Docker image to GHCR
	docker push ghcr.io/v1nshul/prod-cloud-infra-demo:latest

deploy-staging: ## Deploy to staging (requires kubectl configured)
	kubectl apply -k k8s/staging
	kubectl rollout status deployment/app -n prod-cloud-infra-demo-staging

deploy-prod: ## Deploy to production (requires kubectl configured)
	kubectl apply -k k8s/production
	kubectl rollout status deployment/app -n prod-cloud-infra-demo

terraform-init: ## Initialize Terraform
	cd terraform && terraform init

terraform-plan: ## Plan Terraform changes
	cd terraform && terraform plan

terraform-apply: ## Apply Terraform changes
	cd terraform && terraform apply

terraform-destroy: ## Destroy Terraform infrastructure
	cd terraform && terraform destroy

install: ## Install Python dependencies
	pip install -r requirements.txt
	pip install -r requirements-dev.txt

clean: ## Clean up temporary files
	find . -type d -name __pycache__ -exec rm -r {} +
	find . -type f -name "*.pyc" -delete
	find . -type f -name "*.pyo" -delete
	rm -rf .pytest_cache
	rm -rf .coverage
	rm -rf htmlcov

