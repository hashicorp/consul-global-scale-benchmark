BUILD_ID := $(shell git rev-parse --short HEAD 2>/dev/null || echo no-commit-id)
ENVOY_IMAGE_NAME := anubhavmishra/envoy
ENVOY_VERSION := v1.16.0

.DEFAULT_GOAL := help
help: ## List targets & descriptions
	@cat Makefile* | grep -E '^[a-zA-Z_-]+:.*?## .*$$' | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

clean: ## Clean the project
	rm -rf ./build
	mkdir ./build

build-envoy-image: ## Build custom envoy image
	cd config/envoy && docker build -t $(ENVOY_IMAGE_NAME):$(ENVOY_VERSION) .
	cd config/envoy && docker tag $(ENVOY_IMAGE_NAME):$(ENVOY_VERSION) $(ENVOY_IMAGE_NAME):latest

push-envoy-image: ## docker push the service images tagged 'latest' & 'ENVOY_VERSION'
	docker push $(ENVOY_IMAGE_NAME):$(ENVOY_VERSION)
	docker push $(ENVOY_IMAGE_NAME):latest

fmt: ## Format Terraform configuration files
	terraform fmt -recursive infrastructure
	terraform fmt -recursive services