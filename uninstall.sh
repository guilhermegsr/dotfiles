#!/usr/bin/env bash

set -euo pipefail

# Colors
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

info "Uninstalling dotfiles linked from: $DOTFILES_DIR"

unlink_file() {
    local src="$1"
    local dest="$2"

    if [[ -L "$dest" ]]; then
        local current_target
        current_target="$(readlink "$dest")"
        if [[ "$current_target" == "$src" ]]; then
            rm "$dest"
            success "Removed symlink '$dest'"
        else
            warn "Skipping '$dest': symlink points to '$current_target' (expected '$src')"
        fi
    elif [[ -e "$dest" ]]; then
        warn "Skipping '$dest': file/directory exists and is not a symlink"
    fi
}

restore_latest_backup() {
    local target="$1"
    # Look for matching backup files sorted by creation time
    local latest_backup
    latest_backup="$(find "$(dirname "$target")" -maxdepth 1 -name "$(basename "$target").bak.*" 2>/dev/null | sort | tail -n 1)"
    if [[ -n "$latest_backup" && -e "$latest_backup" ]]; then
        info "Found backup '$latest_backup'. Restoring to '$target'..."
        mv "$latest_backup" "$target"
        success "Restored '$target' from backup"
    fi
}

# 1. Remove Zsh symlinks
unlink_file "$DOTFILES_DIR/zsh" "$HOME/.config/zsh"
restore_latest_backup "$HOME/.config/zsh"

unlink_file "$DOTFILES_DIR/zsh/.zshenv" "$HOME/.zshenv"
restore_latest_backup "$HOME/.zshenv"

# 2. Restore default shell to bash if current is zsh
ZSH_PATH="$(command -v zsh 2>/dev/null || true)"
BASH_PATH="$(command -v bash 2>/dev/null || true)"

if [[ -n "$BASH_PATH" && -n "$ZSH_PATH" ]]; then
    CURRENT_SHELL=""
    if command -v getent >/dev/null 2>&1; then
        CURRENT_SHELL="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7 || true)"
    fi
    [[ -z "$CURRENT_SHELL" ]] && CURRENT_SHELL="${SHELL:-}"

    if [[ "$CURRENT_SHELL" == "$ZSH_PATH" ]]; then
        info "Changing default shell back to $BASH_PATH..."
        if command -v chsh >/dev/null 2>&1; then
            if chsh -s "$BASH_PATH"; then
                success "Default shell restored to $BASH_PATH"
            else
                warn "Could not change default shell automatically. Run: chsh -s $BASH_PATH"
            fi
        fi
    fi
fi

success "Dotfiles uninstalled successfully."
