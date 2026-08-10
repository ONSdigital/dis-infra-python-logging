# Parameters
# Pretty
_RESET              := \033[0m
_BOLD               := \033[1m
_COLOUR_GREEN       := \033[32m
_COLOUR_YELLOW      := \033[33m
_COLOUR_BLUE_BOLD   := \033[1;34m

.DEFAULT_GOAL := help

.PHONY: help install lint format test all

help: ## Show help page for list of make targets and variables.
	@echo ""
	@echo "Usage:"
	@echo "    $(_COLOUR_YELLOW)make install$(_RESET) $(_COLOUR_GREEN)Install dependencies$(_RESET)"
	@echo "    $(_COLOUR_YELLOW)make test$(_RESET) $(_COLOUR_GREEN)Run unit tests with coverage$(_RESET)"
	@echo "    $(_COLOUR_YELLOW)make all$(_RESET) $(_COLOUR_GREEN)Run all checks (lint + test)$(_RESET)"
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
