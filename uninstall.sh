#!/usr/bin/env bash

set -euo pipefail

BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

section() {
    printf "\n${CYAN}==>${NC} ${BOLD}%s${NC}\n" "$1"
}

info() {
    printf "  ${BLUE}[INFO]${NC} %s\n" "$1"
}

success() {
    printf "  ${GREEN}[OK]${NC}   %s\n" "$1"
}

warn() {
    printf "  ${YELLOW}[WARN]${NC} %s\n" "$1"
}

error() {
    printf "  ${RED}[ERROR]${NC} %s\n" "$1" >&2
}

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

printf "\n${BOLD}${YELLOW}=== Uninstalling Dotfiles ===${NC}\n"
printf "${DIM}Target: %s${NC}\n" "$DOTFILES_DIR"

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
    else
        info "Nothing to unlink for '$dest'"
    fi
}

restore_latest_backup() {
    local target="$1"
    local latest_backup
    latest_backup="$(find "$(dirname "$target")" -maxdepth 1 -name "$(basename "$target").bak.*" 2>/dev/null | sort | tail -n 1)"
    if [[ -n "$latest_backup" && -e "$latest_backup" ]]; then
        info "Found backup '$latest_backup'. Restoring to '$target'..."
        mv "$latest_backup" "$target"
        success "Restored '$target' from backup"
    fi
}

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"

# 1. Symlinks & Backups
section "Removing symlinks and restoring backups..."

unlink_file "$DOTFILES_DIR/zsh" "$CONFIG_DIR/zsh"
restore_latest_backup "$CONFIG_DIR/zsh"

unlink_file "$DOTFILES_DIR/zsh/.zshenv" "$HOME/.zshenv"
restore_latest_backup "$HOME/.zshenv"

unlink_file "$DOTFILES_DIR/git" "$CONFIG_DIR/git"
restore_latest_backup "$CONFIG_DIR/git"

unlink_file "$DOTFILES_DIR/mise/config.toml" "$CONFIG_DIR/mise/config.toml"
restore_latest_backup "$CONFIG_DIR/mise/config.toml"

unlink_file "$DOTFILES_DIR/tmux" "$CONFIG_DIR/tmux"
restore_latest_backup "$CONFIG_DIR/tmux"

# 2. Nerd Font
section "Checking fonts to remove..."
FONT_DIR=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    FONT_DIR="$HOME/Library/Fonts"
else
    FONT_DIR="$DATA_DIR/fonts"
fi

if [[ -d "$FONT_DIR" ]]; then
    if find "$FONT_DIR" -maxdepth 1 -iname "*JetBrainsMono*Nerd*" 2>/dev/null | grep -q .; then
        info "Removing JetBrainsMono Nerd Font files from '$FONT_DIR'..."
        find "$FONT_DIR" -maxdepth 1 -iname "*JetBrainsMono*Nerd*" -delete 2>/dev/null || true
        if command -v fc-cache >/dev/null 2>&1; then
            fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
        fi
        success "Removed JetBrainsMono Nerd Font"
    else
        info "No JetBrainsMono Nerd Font found in '$FONT_DIR'"
    fi
fi

# 3. Default Shell Restoration
section "Restoring default shell..."
ZSH_PATH="$(command -v zsh 2>/dev/null || true)"
BASH_PATH="$(command -v bash 2>/dev/null || true)"

if [[ -n "$BASH_PATH" && -n "$ZSH_PATH" ]]; then
    CURRENT_USER="${USER:-$(whoami 2>/dev/null || echo "$LOGNAME")}"
    CURRENT_SHELL=""
    if command -v getent >/dev/null 2>&1; then
        CURRENT_SHELL="$(getent passwd "$CURRENT_USER" 2>/dev/null | cut -d: -f7 || true)"
    fi
    [[ -z "$CURRENT_SHELL" ]] && CURRENT_SHELL="${SHELL:-}"

    if [[ "$CURRENT_SHELL" == "$ZSH_PATH" ]]; then
        info "Restoring default shell to $BASH_PATH..."
        if command -v chsh >/dev/null 2>&1; then
            if chsh -s "$BASH_PATH"; then
                success "Default shell restored to $BASH_PATH"
            else
                warn "Could not change default shell automatically. Run: chsh -s $BASH_PATH"
            fi
        fi
    else
        info "Current shell is not Zsh ($CURRENT_SHELL), leaving unchanged"
    fi
fi

printf "\n${BOLD}${GREEN}✔ Dotfiles uninstalled successfully.${NC}\n\n"
