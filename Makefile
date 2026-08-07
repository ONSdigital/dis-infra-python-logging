# Parameters
# Pretty
_RESET              := \033[0m
_BOLD               := \033[1m
_COLOUR_GREEN       := \033[32m
_COLOUR_YELLOW      := \033[33m
_COLOUR_BLUE_BOLD   := \033[1;34m

.DEFAULT_GOAL := help

.PHONY: help install lint format test all release

help: ## Show help page for list of make targets and variables.
	@echo ""
	@echo "Usage:"
	@echo "    $(_COLOUR_YELLOW)make install$(_RESET) $(_COLOUR_GREEN)Install dependencies$(_RESET)"
	@echo "    $(_COLOUR_YELLOW)make test$(_RESET) $(_COLOUR_GREEN)Run unit tests with coverage$(_RESET)"
	@echo "    $(_COLOUR_YELLOW)make all$(_RESET) $(_COLOUR_GREEN)Run all checks (lint + test)$(_RESET)"
	@echo "    $(_COLOUR_YELLOW)make release$(_RESET) $(_COLOUR_GREEN)Create a signed tag and push a release$(_RESET)"
	@echo ""
	@echo "Targets:"
	@awk 'BEGIN {FS = ":.*?## "} \
		/^[a-zA-Z_-]+:.*?##/ {printf "    ${_COLOUR_YELLOW}%-20s${_COLOUR_GREEN}%s${_RESET}\n", $$1, $$2} \
		/^## / {desc = substr($$0, 4)} \
		/^[A-Z0-9_]+ *[:?+]?=/ { \
			if (desc) { \
				split($$0, parts, /[:?+]?=/); \
				var = parts[1]; gsub(/^[ \t]+|[ \t]+$$/, "", var); \
				if (var !~ /^_/) { vars[var] = desc; } \
				desc = ""; \
			} \
		} \
		END { \
			if (length(vars)) { \
				printf "\nVariables:\n"; \
				n = 0; \
				for (v in vars) { n++; keys[n] = v; } \
				for (i = 1; i <= n; i++) { \
					for (j = i + 1; j <= n; j++) { \
						if (keys[i] > keys[j]) { tmp = keys[i]; keys[i] = keys[j]; keys[j] = tmp; } \
					} \
				} \
				for (i = 1; i <= n; i++) { \
					printf "    ${_COLOUR_YELLOW}%-20s${_COLOUR_GREEN}%s${_RESET}\n", keys[i], vars[keys[i]]; \
				} \
			} \
		}' $(MAKEFILE_LIST)

install: ## Install dependencies
	poetry lock && poetry install

lint: install ## Run linting (flake8, black, isort)
	poetry run flake8 src/ tests/
	poetry run black --check src/ tests/
	poetry run isort --check-only src/ tests/

format: install ## Auto-format code (black, isort)
	poetry run black src/ tests/
	poetry run isort src/ tests/

test: install ## Run unit tests with coverage
	poetry run pytest

all: lint test ## Run all checks (lint + test)

release: ## Create a signed tag and push a release (interactive). Requires: gh CLI.
	@echo ""
	@echo "$(_COLOUR_BLUE_BOLD)🚀 Release$(_RESET)"
	@echo ""
	@# Check gh CLI is installed
	@if ! command -v gh &> /dev/null; then \
		echo "$(_COLOUR_YELLOW)Error: 'gh' CLI is not installed. It is required to create GitHub Releases.$(_RESET)"; \
		echo "Install it with: brew install gh"; \
		exit 1; \
	fi
	@# Ensure we're on main
	@CURRENT_BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	if [ "$$CURRENT_BRANCH" != "main" ]; then \
		echo "$(_COLOUR_YELLOW)Error: You must be on 'main' to release. Currently on '$$CURRENT_BRANCH'.$(_RESET)"; \
		exit 1; \
	fi
	@# Check for uncommitted changes
	@if ! git diff --quiet HEAD 2>/dev/null; then \
		echo "$(_COLOUR_YELLOW)Error: You have uncommitted changes. Commit or stash them first.$(_RESET)"; \
		exit 1; \
	fi
	@# Get the latest tag and check HEAD isn't already tagged
	@LATEST_TAG=$$(git tag --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$$' | head -1); \
	if [ -z "$$LATEST_TAG" ]; then \
		LATEST_TAG="v0.0.0"; \
	fi; \
	echo "Current version: $(_COLOUR_BLUE_BOLD)$$LATEST_TAG$(_RESET)"; \
	echo ""; \
	CURRENT_SHA=$$(git rev-parse HEAD); \
	EXISTING_TAG=$$(git tag --points-at $$CURRENT_SHA 2>/dev/null | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$$' | head -1); \
	if [ -n "$$EXISTING_TAG" ]; then \
		echo "$(_COLOUR_YELLOW)Error: HEAD already has tag '$$EXISTING_TAG'. Nothing to release.$(_RESET)"; \
		exit 1; \
	fi; \
	MAJOR=$$(echo $$LATEST_TAG | sed 's/^v//' | cut -d. -f1); \
	MINOR=$$(echo $$LATEST_TAG | sed 's/^v//' | cut -d. -f2); \
	PATCH=$$(echo $$LATEST_TAG | sed 's/^v//' | cut -d. -f3); \
	echo "What type of release?"; \
	echo "  1) patch (v$$MAJOR.$$MINOR.$$((PATCH + 1)))"; \
	echo "  2) minor (v$$MAJOR.$$((MINOR + 1)).0)"; \
	echo "  3) major (v$$((MAJOR + 1)).0.0)"; \
	echo ""; \
	printf "Select (1/2/3): "; \
	read RELEASE_TYPE; \
	case $$RELEASE_TYPE in \
		1) NEW_VERSION="v$$MAJOR.$$MINOR.$$((PATCH + 1))";; \
		2) NEW_VERSION="v$$MAJOR.$$((MINOR + 1)).0";; \
		3) NEW_VERSION="v$$((MAJOR + 1)).0.0";; \
		*) echo "Invalid selection."; exit 1;; \
	esac; \
	echo ""; \
	echo "New version: $(_COLOUR_BLUE_BOLD)$$NEW_VERSION$(_RESET)"; \
	echo ""; \
	echo "Commits since $$LATEST_TAG:"; \
	echo "$(_COLOUR_GREEN)"; \
	if [ "$$LATEST_TAG" = "v0.0.0" ]; then \
		git --no-pager log --oneline --no-decorate; \
	else \
		git --no-pager log --oneline --no-decorate $$LATEST_TAG..HEAD; \
	fi; \
	echo "$(_RESET)"; \
	printf "Create signed tag $$NEW_VERSION? (yes/no): "; \
	read CONFIRM; \
	if [ "$$CONFIRM" != "yes" ]; then \
		echo "Aborted."; \
		exit 1; \
	fi; \
	echo ""; \
	echo "Creating signed tag $$NEW_VERSION..."; \
	if [ "$$LATEST_TAG" = "v0.0.0" ]; then \
		CHANGELOG=$$(git --no-pager log --oneline --reverse); \
	else \
		CHANGELOG=$$(git --no-pager log --oneline --reverse $$LATEST_TAG..HEAD); \
	fi; \
	git tag -s "$$NEW_VERSION" -m "Release $$NEW_VERSION" -m "" -m "$$CHANGELOG"; \
	echo "Pushing tag to origin..."; \
	git push origin "$$NEW_VERSION"; \
	echo "Creating GitHub Release..."; \
	RELEASE_NOTES=$$(printf "## Commits\n\n$$CHANGELOG"); \
	gh release create "$$NEW_VERSION" --title "$$NEW_VERSION" --notes "$$RELEASE_NOTES" --generate-notes --verify-tag; \
	echo ""; \
	echo "$(_COLOUR_GREEN)✅ Released $$NEW_VERSION$(_RESET)"
