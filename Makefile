.DEFAULT_GOAL := help

.PHONY: help install install-offline uninstall doctor backup restore lint check test update

# Single source of truth for the shell files that lint checks. The sourced
# fragments under scripts/install and scripts/uninstall carry a
# `# shellcheck shell=bash` directive so they can be analysed on their own.
SHELL_SOURCES := install.sh uninstall.sh backup.sh restore.sh scripts/*.sh \
	scripts/install/*.sh scripts/uninstall/*.sh tmux/copy.sh

help: ## Display available targets with descriptions
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

install: ## Execute idempotent dotfiles installation with interactive onboarding
	@./install.sh

install-offline: ## Deploy configs without downloading plugins, fonts, Mise, or tools
	@./install.sh --offline

uninstall: ## Revert symlinks, remove dotfiles-managed assets, and restore backups
	@./uninstall.sh

doctor: ## Diagnose links, permissions, configs, plugins, fonts, Mise, and Starship
	@./scripts/doctor.sh

backup: ## Archive local secrets and SSH keys (encrypted by default; ./backup.sh --plain to skip)
	@./backup.sh

restore: ## Restore allowlisted secrets and SSH keys from a backup archive
	@./restore.sh

lint: ## Run static analysis and syntax validation across Bash and Zsh files
	@echo "==> Running ShellCheck"
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -x $(SHELL_SOURCES); \
	elif command -v mise >/dev/null 2>&1 && mise which shellcheck >/dev/null 2>&1; then \
		mise exec -- shellcheck -x $(SHELL_SOURCES); \
	else \
		echo "ShellCheck was not found; skipping static analysis."; \
	fi
	@echo "==> Checking Bash syntax"
	@bash -n $(SHELL_SOURCES)
	@echo "==> Checking Zsh syntax"
	@for f in zsh/.zshenv zsh/.zshrc zsh/local.zsh.example zsh/config/*.zsh zsh/integrations/*.zsh; do \
		zsh -n "$$f" || exit 1; \
	done
	@echo "==> Checking TOML syntax"
	@if command -v python3 >/dev/null 2>&1; then \
		python3 -c 'import pathlib, tomllib; [tomllib.loads(pathlib.Path(path).read_text()) for path in ("mise/config.toml", "starship/starship.toml")]'; \
	else \
		echo "Python 3 was not found; skipping TOML syntax validation."; \
	fi
	@echo "==> Lint passed."

check: lint ## Lint plus backup/restore and shell-helper tests (CI runs this)
	@echo "==> Running backup and restore tests"
	@./scripts/test-backup-restore.sh
	@echo "==> Running shell helper tests"
	@./scripts/test-shell-helpers.sh

test: check ## Alias for check

update: ## Bump pinned plugin SHAs and bootstrap checksums
	@./scripts/update-locks.sh
