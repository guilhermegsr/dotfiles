#!/usr/bin/env bash

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() {
    printf "${BLUE}[INFO]${NC} %s\n" "$1"
}

success() {
    printf "${GREEN}[OK]${NC} %s\n" "$1"
}

warn() {
    printf "${YELLOW}[WARN]${NC} %s\n" "$1"
}

error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1" >&2
}

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info "Installing dotfiles from: $DOTFILES_DIR"

backup_if_exists() {
    local target="$1"
    if [[ -e "$target" && ! -L "$target" ]]; then
        local timestamp
        timestamp="$(date +%Y%m%d_%H%M%S)"
        local backup="${target}.bak.${timestamp}"
        warn "Backing up existing '$target' to '$backup'"
        mv "$target" "$backup"
    fi
}

link_file() {
    local src="$1"
    local dest="$2"

    mkdir -p "$(dirname "$dest")"

    if [[ -L "$dest" ]]; then
        local current_target
        current_target="$(readlink "$dest")"
        if [[ "$current_target" == "$src" ]]; then
            info "'$dest' is already linked to '$src'"
            return 0
        fi
        warn "Replacing existing symlink '$dest' (was pointing to '$current_target')"
        rm "$dest"
    elif [[ -e "$dest" ]]; then
        backup_if_exists "$dest"
    fi

    ln -s "$src" "$dest"
    success "Linked '$dest' -> '$src'"
}

# Zsh
link_file "$DOTFILES_DIR/zsh" "$HOME/.config/zsh"
link_file "$DOTFILES_DIR/zsh/.zshenv" "$HOME/.zshenv"

# Mise
link_file "$DOTFILES_DIR/mise/config.toml" "$HOME/.config/mise/config.toml"

# Bootstrap mise if missing
export PATH="$HOME/.local/bin:$PATH"
MISE_BIN="$(command -v mise 2>/dev/null || true)"

if [[ -z "$MISE_BIN" ]]; then
    if command -v curl >/dev/null 2>&1; then
        info "Installing Mise..."
        curl -fsSL https://mise.run | sh
        MISE_BIN="$HOME/.local/bin/mise"
        success "Mise installed to $MISE_BIN"
    else
        warn "'curl' not found. Install mise manually: https://mise.jdx.dev"
    fi
fi

if [[ -n "$MISE_BIN" && -x "$MISE_BIN" ]]; then
    info "Provisioning tools via Mise..."
    if "$MISE_BIN" install; then
        success "Mise tools installed"
    else
        warn "Some Mise tools failed to install. Run 'mise install' manually."
    fi
fi

# Set Zsh as default shell
ZSH_PATH="$(command -v zsh 2>/dev/null || true)"

if [[ -z "$ZSH_PATH" ]]; then
    warn "Zsh is not installed. Please install Zsh and set it as your default shell."
else
    CURRENT_USER="${USER:-$(whoami 2>/dev/null || echo "$LOGNAME")}"
    CURRENT_SHELL=""
    if command -v getent >/dev/null 2>&1; then
        CURRENT_SHELL="$(getent passwd "$CURRENT_USER" 2>/dev/null | cut -d: -f7 || true)"
    fi
    [[ -z "$CURRENT_SHELL" ]] && CURRENT_SHELL="${SHELL:-}"

    if [[ "$CURRENT_SHELL" != "$ZSH_PATH" ]]; then
        info "Changing default shell to $ZSH_PATH..."
        if command -v chsh >/dev/null 2>&1; then
            if chsh -s "$ZSH_PATH"; then
                success "Default shell changed to $ZSH_PATH"
            else
                warn "Could not change default shell automatically. Run: chsh -s $ZSH_PATH"
            fi
        else
            warn "'chsh' command not found. Please set $ZSH_PATH as default shell manually."
        fi
    else
        info "Zsh is already the default shell ($ZSH_PATH)"
    fi
fi

success "Dotfiles installation completed successfully!"