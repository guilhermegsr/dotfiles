# shellcheck shell=bash

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

dotfiles_state_dir() {
    printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
}

dotfiles_previous_shell_file() {
    printf '%s/previous-shell\n' "$(dotfiles_state_dir)"
}

# A directory of its own: the family is 96 files, and removal must never
# have to guess which of them came from here.
dotfiles_font_dir() {
    printf '%s/JetBrainsMonoNerdFont\n' "$(dotfiles_legacy_font_dir "$1")"
}

dotfiles_legacy_font_dir() {
    local data_dir="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        printf '%s/Library/Fonts\n' "$HOME"
    else
        printf '%s/fonts\n' "$data_dir"
    fi
}

# Entries are bare file names; a path separator means a manifest that was
# tampered with. Reports through REMOVED_FONT_COUNT.
remove_manifest_fonts() {
    local font_dir="$1"
    local manifest="$2"
    local font_name font_path
    REMOVED_FONT_COUNT=0
    [[ -f "$manifest" && -d "$font_dir" ]] || return 0
    while IFS= read -r font_name || [[ -n "$font_name" ]]; do
        [[ -z "$font_name" ]] && continue
        if [[ "$font_name" == */* || "$font_name" == "." || "$font_name" == ".." ]]; then
            warn "Skipping invalid font manifest entry: $font_name"
            continue
        fi
        font_path="$font_dir/$font_name"
        if [[ -e "$font_path" || -L "$font_path" ]]; then
            rm -f "$font_path"
            REMOVED_FONT_COUNT=$((REMOVED_FONT_COUNT + 1))
        fi
    done <"$manifest"
}

# A run killed outright leaves a half-written copy of whatever it staged.
# The age floor keeps this from deleting what a live run still owns.
sweep_stale_staging() {
    local parent="$1"
    local pattern="$2"
    local stale
    [[ -d "$parent" ]] || return 0
    while IFS= read -r stale; do
        [[ -n "$stale" ]] || continue
        rm -rf "$stale"
        info "Removed a staging directory left by an interrupted run: $stale"
    done < <(find "$parent" -maxdepth 1 -type d -name "$pattern" -mmin +1440 2>/dev/null)
}

# The installer seeds a few files from an example so there is something to
# edit. Until they are edited they carry nothing, and an uninstall that leaves
# them behind is leaving its own litter.
file_is_untouched_template() {
    local target="$1"
    local template="${2:-}"

    [[ -f "$target" && ! -L "$target" ]] || return 1
    if [[ -n "$template" ]]; then
        cmp -s "$target" "$template"
    else
        [[ ! -s "$target" ]]
    fi
}

remove_untouched_file() {
    local target="$1"
    local template="${2:-}"

    [[ -e "$target" || -L "$target" ]] || return 0
    if file_is_untouched_template "$target" "$template"; then
        rm -f "$target"
        success "Removed unmodified $target"
    else
        info "Keeping $target; it holds your own settings now"
    fi
}

backup_if_exists() {
    local target="$1"
    if [[ -e "$target" || -L "$target" ]]; then
        local timestamp counter
        timestamp="$(date +%Y%m%d_%H%M%S)"
        local backup="${target}.bak.${timestamp}"
        counter=0
        while [[ -e "$backup" || -L "$backup" ]]; do
            counter=$((counter + 1))
            printf -v backup '%s.bak.%s.%03d' "$target" "$timestamp" "$counter"
        done
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
        backup_if_exists "$dest"
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
    if [[ -e "$target" || -L "$target" ]]; then
        return 0
    fi
    parent="$(dirname "$target")"
    [[ -d "$parent" ]] || return 0
    latest_backup="$(find "$parent" -maxdepth 1 -name "$(basename "$target").bak.*" 2>/dev/null | sort | tail -n 1)"
    if [[ -n "$latest_backup" && ( -e "$latest_backup" || -L "$latest_backup" ) ]]; then
        info "Restoring $target from $latest_backup"
        mv "$latest_backup" "$target"
        success "Restored $target"
    fi
}
