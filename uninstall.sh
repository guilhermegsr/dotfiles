#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$DOTFILES_DIR/scripts/lib.sh"

printf "\n%b=== Uninstall ===%b\n" "${BOLD}${YELLOW}" "$NC"
printf "%bTarget: %s%b\n" "$DIM" "$DOTFILES_DIR" "$NC"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"

section "Symlinks"
unlink_file "$DOTFILES_DIR/zsh/.zshrc" "$CONFIG_DIR/zsh/.zshrc"
restore_latest_backup "$CONFIG_DIR/zsh/.zshrc"
unlink_file "$DOTFILES_DIR/zsh/.zshenv" "$CONFIG_DIR/zsh/.zshenv"
restore_latest_backup "$CONFIG_DIR/zsh/.zshenv"
unlink_file "$DOTFILES_DIR/zsh/config" "$CONFIG_DIR/zsh/config"
restore_latest_backup "$CONFIG_DIR/zsh/config"
unlink_file "$DOTFILES_DIR/zsh/integrations" "$CONFIG_DIR/zsh/integrations"
restore_latest_backup "$CONFIG_DIR/zsh/integrations"

# Pre-layout-change whole-dir symlink.
unlink_file "$DOTFILES_DIR/zsh" "$CONFIG_DIR/zsh"
restore_latest_backup "$CONFIG_DIR/zsh"

unlink_file "$DOTFILES_DIR/zsh/.zshenv" "$HOME/.zshenv"
restore_latest_backup "$HOME/.zshenv"

unlink_file "$DOTFILES_DIR/git/config" "$CONFIG_DIR/git/config"
restore_latest_backup "$CONFIG_DIR/git/config"
unlink_file "$DOTFILES_DIR/git/ignore" "$CONFIG_DIR/git/ignore"
restore_latest_backup "$CONFIG_DIR/git/ignore"
unlink_file "$DOTFILES_DIR/git" "$CONFIG_DIR/git"
restore_latest_backup "$CONFIG_DIR/git"

unlink_file "$DOTFILES_DIR/mise/config.toml" "$CONFIG_DIR/mise/config.toml"
restore_latest_backup "$CONFIG_DIR/mise/config.toml"
unlink_file "$DOTFILES_DIR/mise/mise.lock" "$CONFIG_DIR/mise/mise.lock"
restore_latest_backup "$CONFIG_DIR/mise/mise.lock"

unlink_file "$DOTFILES_DIR/tmux" "$CONFIG_DIR/tmux"
restore_latest_backup "$CONFIG_DIR/tmux"

unlink_file "$DOTFILES_DIR/alacritty" "$CONFIG_DIR/alacritty"
restore_latest_backup "$CONFIG_DIR/alacritty"

unlink_file "$DOTFILES_DIR/ssh/config" "$HOME/.ssh/config"
restore_latest_backup "$HOME/.ssh/config"

section "Fonts"
FONT_DIR=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    FONT_DIR="$HOME/Library/Fonts"
else
    FONT_DIR="$DATA_DIR/fonts"
fi

if [[ -d "$FONT_DIR" ]]; then
    if find "$FONT_DIR" -maxdepth 1 -iname "*JetBrainsMono*Nerd*" 2>/dev/null | grep -q .; then
        info "Removing JetBrainsMono Nerd Font from $FONT_DIR"
        find "$FONT_DIR" -maxdepth 1 -iname "*JetBrainsMono*Nerd*" -delete 2>/dev/null || true
        if command -v fc-cache >/dev/null 2>&1; then
            fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
        fi
        success "Removed JetBrainsMono Nerd Font"
    else
        info "No JetBrainsMono Nerd Font files in $FONT_DIR"
    fi
fi

section "Login shell"
PREVIOUS_SHELL_FILE="$(dotfiles_previous_shell_file)"
if [[ -f "$PREVIOUS_SHELL_FILE" ]]; then
    PREVIOUS_SHELL="$(tr -d '\n' <"$PREVIOUS_SHELL_FILE")"
    if [[ -z "$PREVIOUS_SHELL" ]]; then
        warn "Saved previous shell is empty. Leaving the login shell unchanged."
    elif [[ "${DOTFILES_SKIP_CHSH:-}" == 1 ]]; then
        info "Skipping chsh; would restore $PREVIOUS_SHELL"
        rm -f "$PREVIOUS_SHELL_FILE"
    elif command -v chsh >/dev/null 2>&1; then
        info "Restoring login shell to $PREVIOUS_SHELL"
        if chsh -s "$PREVIOUS_SHELL"; then
            success "Login shell restored to $PREVIOUS_SHELL"
            rm -f "$PREVIOUS_SHELL_FILE"
        else
            warn "Could not restore the login shell. Run: chsh -s $PREVIOUS_SHELL"
        fi
    else
        warn "chsh was not found. Restore the login shell with: chsh -s $PREVIOUS_SHELL"
    fi
else
    info "No saved previous shell. Leaving the login shell unchanged."
fi

printf "\n%bUninstall complete.%b\n\n" "${BOLD}${GREEN}" "$NC"
