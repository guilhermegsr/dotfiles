.DEFAULT_GOAL := help

.PHONY: help install uninstall lint check test update

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

install: ## Install dotfiles and create symlinks
	@./install.sh

uninstall: ## Uninstall dotfiles and restore backups
	@./uninstall.sh

lint: ## Validate syntax and style for Shell and Zsh scripts
	@echo "==> Running ShellCheck..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck install.sh uninstall.sh; \
	else \
		echo "ShellCheck not found, skipping static analysis."; \
	fi
	@echo "==> Checking Bash syntax..."
	@bash -n install.sh uninstall.sh
	@echo "==> Checking Zsh syntax..."
	@for f in zsh/.zshenv zsh/.zshrc zsh/local.zsh.example zsh/config/*.zsh zsh/integrations/*.zsh; do \
		zsh -n "$$f" || exit 1; \
	done
	@echo "==> All scripts passed validation!"

check: lint ## Alias for lint

update: ## Upgrade Mise tools and pull latest Zsh plugins
	@echo "==> Upgrading tools managed by Mise..."
	@if command -v mise >/dev/null 2>&1; then mise upgrade; fi
	@echo "==> Updating Zsh plugins..."
	@PLUGIN_DIR="$${XDG_DATA_HOME:-$$HOME/.local/share}/zsh/plugins"; \
	for plugin in "$$PLUGIN_DIR"/*; do \
		if [ -d "$$plugin/.git" ]; then \
			echo "Updating $$(basename "$$plugin")..."; \
			git -C "$$plugin" pull --ff-only --quiet || echo "Warning: Could not update $$(basename "$$plugin")"; \
		fi \
	done
	@echo "==> Updates completed successfully!"
