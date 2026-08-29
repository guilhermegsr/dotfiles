.DEFAULT_GOAL := help

.PHONY: help install uninstall backup restore lint check update

help: ## Display available targets with descriptions
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

install: ## Execute idempotent dotfiles installation with interactive onboarding
	@./install.sh

uninstall: ## Revert symlinks, remove dotfiles-managed assets, and restore backups
	@./uninstall.sh

backup: ## Archive local secrets, private configs, and SSH keys (optional AES-256 encryption)
	@./backup.sh

restore: ## Restore local secrets, private configs, and SSH keys from a backup archive
	@./restore.sh

lint: ## Run static analysis and syntax validation across Bash and Zsh files
	@echo "==> Running ShellCheck analysis..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck install.sh uninstall.sh backup.sh restore.sh; \
	elif command -v mise >/dev/null 2>&1 && mise which shellcheck >/dev/null 2>&1; then \
		mise exec -- shellcheck install.sh uninstall.sh backup.sh restore.sh; \
	else \
		echo "Notice: ShellCheck not found; skipping static analysis."; \
	fi
	@echo "==> Validating Bash script syntax..."
	@bash -n install.sh uninstall.sh backup.sh restore.sh
	@echo "==> Validating Zsh script syntax..."
	@for f in zsh/.zshenv zsh/.zshrc zsh/local.zsh.example zsh/config/*.zsh zsh/integrations/*.zsh; do \
		zsh -n "$$f" || exit 1; \
	done
	@echo "==> All scripts passed validation."

check: lint ## Alias for lint

update: ## Upgrade Mise-managed toolchains and pull upstream Zsh plugins
	@echo "==> Upgrading tools managed by Mise..."
	@if command -v mise >/dev/null 2>&1; then mise upgrade; fi
	@echo "==> Pulling latest updates for Zsh plugins..."
	@PLUGIN_DIR="$${XDG_DATA_HOME:-$$HOME/.local/share}/zsh/plugins"; \
	for plugin in "$$PLUGIN_DIR"/*; do \
		if [ -d "$$plugin/.git" ]; then \
			echo "Updating $$(basename "$$plugin")..."; \
			git -C "$$plugin" pull --ff-only --quiet || echo "Warning: Failed to update $$(basename "$$plugin")"; \
		fi \
	done
	@echo "==> Update process completed."
