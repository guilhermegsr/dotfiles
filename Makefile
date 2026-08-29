.DEFAULT_GOAL := help

.PHONY: help install uninstall lint check test update

help: ## Mostra esta mensagem de ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

install: ## Instala os dotfiles e cria os links simbólicos
	@./install.sh

uninstall: ## Desinstala os dotfiles e restaura backups
	@./uninstall.sh

lint: ## Valida a sintaxe de todos os scripts Shell e Zsh
	@echo "==> Verificando sintaxe Bash..."
	@bash -n install.sh uninstall.sh
	@echo "==> Verificando sintaxe Zsh..."
	@for f in zsh/.zshenv zsh/.zshrc zsh/local.zsh.example zsh/config/*.zsh zsh/integrations/*.zsh; do \
		zsh -n "$$f" || exit 1; \
	done
	@echo "==> Todos os scripts estão com a sintaxe válida!"

check: lint ## Alias para lint

update: ## Atualiza as ferramentas do Mise e os plugins do Zsh
	@echo "==> Atualizando ferramentas gerenciadas pelo Mise..."
	@if command -v mise >/dev/null 2>&1; then mise upgrade; fi
	@echo "==> Atualizando plugins do Zsh..."
	@PLUGIN_DIR="$${XDG_DATA_HOME:-$$HOME/.local/share}/zsh/plugins"; \
	for plugin in "$$PLUGIN_DIR"/*; do \
		if [ -d "$$plugin/.git" ]; then \
			echo "Atualizando $$(basename "$$plugin")..."; \
			git -C "$$plugin" pull --quiet; \
		fi \
	done
	@echo "==> Atualizações concluídas!"
