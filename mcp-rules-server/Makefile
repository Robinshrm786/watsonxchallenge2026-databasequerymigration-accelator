# Makefile for mcp-rules-server
# MCP Server built with chuk-mcp-runtime

.PHONY: venv activate install clean run test lint format help

# Default shell
SHELL := /bin/bash

# Virtual environment directory
VENV := .venv
PYTHON := $(VENV)/bin/python
UV := uv

# Color output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
NC := \033[0m # No Color

help: ## Show this help message
	@echo -e "$(BLUE)mcp-rules-server - Makefile Commands$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""

venv: ## Create a new virtual environment using uv venv
	@echo -e "$(BLUE)Creating virtual environment...$(NC)"
	@if [ ! -d "$(VENV)" ]; then \
		$(UV) venv $(VENV); \
		echo -e "$(GREEN)✓ Virtual environment created at $(VENV)$(NC)"; \
	else \
		echo -e "$(YELLOW)Virtual environment already exists$(NC)"; \
	fi

activate: ## Activate the virtual environment (use: source .venv/bin/activate)
	@echo -e "$(YELLOW)To activate the virtual environment, run:$(NC)"
	@echo "  source $(VENV)/bin/activate"

install: venv ## Install project dependencies using uv pip
	@echo -e "$(BLUE)Installing dependencies...$(NC)"
	@$(UV) pip install -e ".[dev]"
	@echo -e "$(GREEN)✓ Dependencies installed$(NC)"

clean: ## Clean up venv, build artifacts, and Python caches
	@echo -e "$(BLUE)Cleaning up...$(NC)"
	@rm -rf $(VENV)
	@rm -rf build/
	@rm -rf dist/
	@rm -rf *.egg-info
	@rm -rf .pytest_cache
	@rm -rf .ruff_cache
	@find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete
	@find . -type f -name "*.pyo" -delete
	@find . -type f -name "*.coverage" -delete
	@echo -e "$(GREEN)✓ Cleanup complete$(NC)"

run: ## Run the MCP Server
	@echo -e "$(BLUE)Starting MCP Server...$(NC)"
	@$(PYTHON) -m mcp_rules_server.main

test: ## Run unit tests using pytest
	@echo -e "$(BLUE)Running tests...$(NC)"
	@$(PYTHON) -m pytest test/ -v

lint: ## Run ruff for linting
	@echo -e "$(BLUE)Running linter...$(NC)"
	@$(PYTHON) -m ruff check .

format: ## Auto-format code with ruff
	@echo -e "$(BLUE)Formatting code...$(NC)"
	@$(PYTHON) -m ruff check --fix .
	@$(PYTHON) -m ruff format .
	@echo -e "$(GREEN)✓ Code formatted$(NC)"

# Development workflow shortcuts
.PHONY: dev check

dev: install ## Setup development environment (venv + install)
	@echo -e "$(GREEN)✓ Development environment ready!$(NC)"
	@echo -e "$(YELLOW)Run 'make activate' to activate the virtual environment$(NC)"

check: lint test ## Run linting and tests
	@echo -e "$(GREEN)✓ All checks passed!$(NC)"