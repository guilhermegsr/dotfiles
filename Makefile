.DEFAULT_GOAL := help

.PHONY: help install uninstall backup restore lint check test update

help: ## Display available targets with descriptions
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

install: ## Execute idempotent dotfiles installation with interactive onboarding
	@./install.sh

uninstall: ## Revert symlinks, remove dotfiles-managed assets, and restore backups
	@./uninstall.sh

backup: ## Archive local secrets and SSH keys (encrypted by default; ./backup.sh --plain to skip)
	@./backup.sh

restore: ## Restore allowlisted secrets and SSH keys from a backup archive
	@./restore.sh

lint: ## Run static analysis and syntax validation across Bash and Zsh files
	@echo "==> Running ShellCheck analysis..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -x install.sh uninstall.sh backup.sh restore.sh scripts/*.sh; \
	elif command -v mise >/dev/null 2>&1 && mise which shellcheck >/dev/null 2>&1; then \
		mise exec -- shellcheck -x install.sh uninstall.sh backup.sh restore.sh scripts/*.sh; \
	else \
		echo "Notice: ShellCheck not found; skipping static analysis."; \
	fi
	@echo "==> Validating Bash script syntax..."
	@bash -n install.sh uninstall.sh backup.sh restore.sh scripts/*.sh
	@echo "==> Validating Zsh script syntax..."
	@for f in zsh/.zshenv zsh/.zshrc zsh/local.zsh.example zsh/config/*.zsh zsh/integrations/*.zsh; do \
		zsh -n "$$f" || exit 1; \
	done
	@echo "==> All scripts passed validation."

check: lint ## Alias for lint

test: lint ## Run lint plus backup/restore allowlist and encryption tests
	@echo "==> Running backup/restore tests..."
	@./scripts/test-backup-restore.sh

update: ## Bump pinned plugin SHAs, bootstrap checksums, and Mise lockfile
	@./scripts/update-locks.sh
