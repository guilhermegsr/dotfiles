#!/usr/bin/env bash

BOLD='\033[1m'
# shellcheck disable=SC2034
DIM='\033[2m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

section() {
    printf "\n%b==>%b %b%s%b\n" "$CYAN" "$NC" "$BOLD" "$1" "$NC"
}

info() {
    printf "  %b[INFO]%b %s\n" "$BLUE" "$NC" "$1"
}

success() {
    printf "  %b[OK]%b   %s\n" "$GREEN" "$NC" "$1"
}

warn() {
    printf "  %b[WARN]%b %s\n" "$YELLOW" "$NC" "$1"
}

error() {
    printf "  %b[ERROR]%b %s\n" "$RED" "$NC" "$1" >&2
}

dotfiles_previous_shell_file() {
    printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/previous-shell"
}

backup_if_exists() {
    local target="$1"
    if [[ -e "$target" && ! -L "$target" ]]; then
        local timestamp
        timestamp="$(date +%Y%m%d_%H%M%S)"
        local backup="${target}.bak.${timestamp}"
        warn "Backing up $target to $backup"
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
            info "Already linked: $dest"
            return 0
        fi
        warn "Replacing symlink $dest, currently pointing to $current_target"
        rm "$dest"
    elif [[ -e "$dest" ]]; then
        backup_if_exists "$dest"
    fi

    ln -s "$src" "$dest"
    success "Linked $dest to $src"
}

unlink_file() {
    local src="$1"
    local dest="$2"

    if [[ -L "$dest" ]]; then
        local current_target
        current_target="$(readlink "$dest")"
        if [[ "$current_target" == "$src" ]]; then
            rm "$dest"
            success "Removed symlink $dest"
        else
            warn "Skipping $dest; it points to $current_target"
        fi
    elif [[ -e "$dest" ]]; then
        warn "Skipping $dest because it is not a symlink"
    else
        info "Nothing to unlink at $dest"
    fi
}

restore_latest_backup() {
    local target="$1"
    local latest_backup parent
    if [[ -e "$target" ]]; then
        return 0
    fi
    parent="$(dirname "$target")"
    [[ -d "$parent" ]] || return 0
    latest_backup="$(find "$parent" -maxdepth 1 -name "$(basename "$target").bak.*" 2>/dev/null | sort | tail -n 1)"
    if [[ -n "$latest_backup" && -e "$latest_backup" ]]; then
        info "Restoring $target from $latest_backup"
        mv "$latest_backup" "$target"
        success "Restored $target"
    fi
}
