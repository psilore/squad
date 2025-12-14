.PHONY: help build run test lint lint-docker lint-yaml lint-shell clean

# Variables
IMAGE_NAME := squad
IMAGE_TAG := test
DOCKER_RUN_FLAGS := --rm -v $(PWD)/output:/workspace/report
GITHUB_TOKEN ?= $(shell echo $$GITHUB_TOKEN)
OWNER ?= psilore

# Default target
help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build the Docker image
	@echo "🏗️  Building Docker image..."
	@docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .
	@echo "✅ Build complete"

run: build ## Build and run the Docker container
	@echo "🚀 Running Squad..."
	@mkdir -p output
	@chmod 777 output
	@docker run $(DOCKER_RUN_FLAGS) \
		-e GITHUB_TOKEN=$(GITHUB_TOKEN) \
		-e INPUT_OWNER=$(OWNER) \
		$(IMAGE_NAME):$(IMAGE_TAG)
	@echo "✅ Report generated in ./output/"

test: lint ## Run all tests and linting
	@echo "🧪 Running tests..."
	@docker run --rm $(IMAGE_NAME):$(IMAGE_TAG) /bin/bash -c "which gh && which jq && which git && echo '✅ Dependencies verified'"
	@echo "✅ All tests passed"

lint: lint-docker lint-yaml lint-shell ## Run all linters

lint-docker: ## Lint Dockerfile with Hadolint
	@echo "🔍 Linting Dockerfile..."
	@docker run --rm -i hadolint/hadolint < Dockerfile
	@echo "✅ Dockerfile lint passed"

lint-yaml: ## Lint YAML files with yamllint
	@echo "🔍 Linting YAML files..."
	@docker run --rm -v "$(PWD):/data" cytopia/yamllint -c .github/.yamllintrc.yml .
	@echo "✅ YAML lint passed"

lint-shell: ## Lint shell scripts with ShellCheck
	@echo "🔍 Linting shell scripts..."
	@docker run --rm -v "$(PWD):/mnt" koalaman/shellcheck:stable scripts/*.sh
	@echo "✅ Shell script lint passed"

clean: ## Clean generated files and Docker images
	@echo "🧹 Cleaning up..."
	@rm -rf output/
	@docker rmi -f $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
	@echo "✅ Cleanup complete"

verify-deps: build ## Verify Docker image dependencies
	@echo "🔍 Verifying dependencies..."
	@docker run --rm $(IMAGE_NAME):$(IMAGE_TAG) /bin/bash -c "bash --version && git --version && gh --version && jq --version && echo '✅ All dependencies verified'"

quick-run: ## Quick run without rebuilding (requires GITHUB_TOKEN)
	@mkdir -p output
	@chmod 777 output
	@docker run $(DOCKER_RUN_FLAGS) \
		-e GITHUB_TOKEN=$(GITHUB_TOKEN) \
		-e INPUT_OWNER=$(OWNER) \
		$(IMAGE_NAME):$(IMAGE_TAG)
