#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$DOTFILES_DIR/scripts/lib.sh"
# shellcheck source=scripts/lock-utils.sh
source "$DOTFILES_DIR/scripts/lock-utils.sh"
# shellcheck source=scripts/uninstall/purge.sh
source "$DOTFILES_DIR/scripts/uninstall/purge.sh"

PURGE=false

usage() {
    cat <<'EOF'
Usage: ./uninstall.sh [--purge]

Options:
  --purge     Also remove plugins and the Mise binary recorded as dotfiles-owned
  -h, --help  Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --purge)
            PURGE=true
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            usage >&2
            exit 2
            ;;
    esac
    shift
done

printf "\n%b=== Uninstall ===%b\n" "${BOLD}${YELLOW}" "$NC"
printf "%bTarget: %s%b\n" "$DIM" "$DOTFILES_DIR" "$NC"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_DIR="$(dotfiles_state_dir)"

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
if [[ -L "$CONFIG_DIR/zsh" ]]; then
    unlink_file "$DOTFILES_DIR/zsh" "$CONFIG_DIR/zsh"
    restore_latest_backup "$CONFIG_DIR/zsh"
fi

unlink_file "$DOTFILES_DIR/zsh/.zshenv" "$HOME/.zshenv"
restore_latest_backup "$HOME/.zshenv"

# Pre-migration installs symlinked the global Git config into the repository.
if [[ -L "$CONFIG_DIR/git/config" ]]; then
    unlink_file "$DOTFILES_DIR/git/config" "$CONFIG_DIR/git/config"
    restore_latest_backup "$CONFIG_DIR/git/config"
fi

# Machine-local file: drop our include, keep whatever else it holds.
GIT_GLOBAL_CONFIG="$CONFIG_DIR/git/config"
if [[ -f "$GIT_GLOBAL_CONFIG" && ! -L "$GIT_GLOBAL_CONFIG" ]]; then
    git_includes=()
    while IFS= read -r include_path; do
        git_includes+=("$include_path")
    done < <(git config --file "$GIT_GLOBAL_CONFIG" --get-all include.path 2>/dev/null || true)

    if printf '%s\n' "${git_includes[@]+"${git_includes[@]}"}" | grep -qxF "$DOTFILES_DIR/git/config"; then
        git config --file "$GIT_GLOBAL_CONFIG" --unset-all include.path || true
        for include_path in "${git_includes[@]+"${git_includes[@]}"}"; do
            [[ "$include_path" == "$DOTFILES_DIR/git/config" ]] && continue
            git config --file "$GIT_GLOBAL_CONFIG" --add include.path "$include_path"
        done
        success "Removed the dotfiles include from $GIT_GLOBAL_CONFIG"
    else
        info "No dotfiles include in $GIT_GLOBAL_CONFIG"
    fi
fi
unlink_file "$DOTFILES_DIR/git/ignore" "$CONFIG_DIR/git/ignore"
restore_latest_backup "$CONFIG_DIR/git/ignore"
if [[ -L "$CONFIG_DIR/git" ]]; then
    unlink_file "$DOTFILES_DIR/git" "$CONFIG_DIR/git"
    restore_latest_backup "$CONFIG_DIR/git"
fi

unlink_file "$DOTFILES_DIR/mise/config.toml" "$CONFIG_DIR/mise/config.toml"
restore_latest_backup "$CONFIG_DIR/mise/config.toml"

# Cleanup for installs created before Mise lockfiles were disabled.
unlink_file "$DOTFILES_DIR/mise/mise.lock" "$CONFIG_DIR/mise/mise.lock"
restore_latest_backup "$CONFIG_DIR/mise/mise.lock"

unlink_file "$DOTFILES_DIR/starship/starship.toml" "$CONFIG_DIR/starship.toml"
restore_latest_backup "$CONFIG_DIR/starship.toml"

unlink_file "$DOTFILES_DIR/tmux" "$CONFIG_DIR/tmux"
restore_latest_backup "$CONFIG_DIR/tmux"

unlink_file "$DOTFILES_DIR/alacritty" "$CONFIG_DIR/alacritty"
restore_latest_backup "$CONFIG_DIR/alacritty"

unlink_file "$DOTFILES_DIR/ssh/config" "$HOME/.ssh/config"
restore_latest_backup "$HOME/.ssh/config"

# Directories the installer created and nothing else claimed. rmdir refuses a
# directory that still holds anything, so local overrides and keys stay put.
rmdir "$CONFIG_DIR/mise" "$CONFIG_DIR/git" "$CONFIG_DIR/zsh" \
    "$HOME/.ssh/sockets" "$HOME/.ssh/conf.d" \
    "$HOME/.ssh/keys/personal" "$HOME/.ssh/keys/work" "$HOME/.ssh/keys/servers" \
    "$HOME/.ssh/keys" 2>/dev/null || true

section "Fonts"
FONT_DIR=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    FONT_DIR="$HOME/Library/Fonts"
else
    FONT_DIR="$DATA_DIR/fonts"
fi
FONT_MANIFEST="$STATE_DIR/installed-fonts"

if [[ -f "$FONT_MANIFEST" ]]; then
    removed_font_count=0
    while IFS= read -r font_name || [[ -n "$font_name" ]]; do
        [[ -z "$font_name" ]] && continue
        if [[ "$font_name" == */* || "$font_name" == "." || "$font_name" == ".." ]]; then
            warn "Skipping invalid font manifest entry: $font_name"
            continue
        fi
        font_path="$FONT_DIR/$font_name"
        if [[ -e "$font_path" || -L "$font_path" ]]; then
            rm -f "$font_path"
            removed_font_count=$((removed_font_count + 1))
        fi
    done <"$FONT_MANIFEST"
    rm -f "$FONT_MANIFEST"

    if [[ $removed_font_count -gt 0 ]]; then
        info "Removed $removed_font_count dotfiles-managed font files from $FONT_DIR"
        if command -v fc-cache >/dev/null 2>&1; then
            fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
        fi
        success "Removed dotfiles-managed JetBrainsMono Nerd Font files"
    else
        info "No dotfiles-managed font files were present"
    fi
else
    info "No managed font manifest; leaving existing fonts untouched"
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

if [[ "$PURGE" == true ]]; then
    purge_managed_assets
fi

printf "\n%bUninstall complete.%b\n\n" "${BOLD}${GREEN}" "$NC"
