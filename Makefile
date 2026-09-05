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
	@echo "==> Running ShellCheck"
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -x install.sh uninstall.sh backup.sh restore.sh scripts/*.sh tmux/copy.sh; \
	elif command -v mise >/dev/null 2>&1 && mise which shellcheck >/dev/null 2>&1; then \
		mise exec -- shellcheck -x install.sh uninstall.sh backup.sh restore.sh scripts/*.sh tmux/copy.sh; \
	else \
		echo "ShellCheck was not found; skipping static analysis."; \
	fi
	@echo "==> Checking Bash syntax"
	@bash -n install.sh uninstall.sh backup.sh restore.sh scripts/*.sh tmux/copy.sh
	@echo "==> Checking Zsh syntax"
	@for f in zsh/.zshenv zsh/.zshrc zsh/local.zsh.example zsh/config/*.zsh zsh/integrations/*.zsh; do \
		zsh -n "$$f" || exit 1; \
	done
	@echo "==> Lint passed."

check: lint ## Lint plus backup/restore and shell-helper tests (CI runs this)
	@echo "==> Running backup and restore tests"
	@./scripts/test-backup-restore.sh
	@echo "==> Running shell helper tests"
	@./scripts/test-shell-helpers.sh

test: check ## Alias for check

update: ## Bump pinned plugin SHAs, bootstrap checksums, tool versions, and Mise lockfile
	@./scripts/update-locks.sh
