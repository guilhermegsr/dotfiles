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

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lock-utils.sh
source "$DOTFILES_DIR/scripts/lock-utils.sh"

load_bootstrap_lock "$DOTFILES_DIR/locks/bootstrap.lock"

printf "\n%b=== Dotfiles Installation ===%b\n" "${BOLD}${BLUE}" "$NC"
printf "%bSource: %s%b\n" "$DIM" "$DOTFILES_DIR" "$NC"

backup_if_exists() {
    local target="$1"
    if [[ -e "$target" && ! -L "$target" ]]; then
        local timestamp
        timestamp="$(date +%Y%m%d_%H%M%S)"
        local backup="${target}.bak.${timestamp}"
        warn "Backing up existing non-symlink target '$target' to '$backup'"
        mv "$target" "$backup"
    fi
}

# Replace a legacy directory symlink with a real directory so local secrets
# (local.zsh, config.local) live outside the git working tree.
ensure_config_dir() {
    local dest="$1"
    if [[ -L "$dest" ]]; then
        warn "Replacing directory symlink '$dest' with a real directory"
        rm "$dest"
    elif [[ -e "$dest" && ! -d "$dest" ]]; then
        backup_if_exists "$dest"
    fi
    mkdir -p "$dest"
}

migrate_secret() {
    local src="$1"
    local dest="$2"
    if [[ -f "$src" && ! -e "$dest" ]]; then
        cp "$src" "$dest"
        chmod 600 "$dest"
        info "Migrated '$src' -> '$dest'"
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
            info "'$dest' already correctly linked"
            return 0
        fi
        warn "Replacing stale symlink '$dest' (points to '$current_target')"
        rm "$dest"
    elif [[ -e "$dest" ]]; then
        backup_if_exists "$dest"
    fi

    ln -s "$src" "$dest"
    success "Linked '$dest' -> '$src'"
}

install_plugin_at_sha() {
    local name="$1"
    local url="$2"
    local sha="$3"
    local dir="$PLUGIN_DIR/$name"

    if [[ ! "$sha" =~ ^[0-9a-f]{7,40}$ ]]; then
        error "Invalid plugin SHA for '$name': $sha"
        exit 1
    fi

    if [[ -d "$dir/.git" ]]; then
        local current
        current="$(git -C "$dir" rev-parse HEAD)"
        if [[ "$current" == "$sha" ]]; then
            info "$name already pinned at ${sha:0:12}"
            return 0
        fi
        info "Updating $name to ${sha:0:12}..."
        git -C "$dir" fetch --depth 1 origin "$sha"
        git -C "$dir" checkout --detach "$sha"
    else
        rm -rf "$dir"
        mkdir -p "$dir"
        info "Cloning $name at ${sha:0:12}..."
        git -C "$dir" init --quiet
        git -C "$dir" remote add origin "$url"
        git -C "$dir" fetch --depth 1 origin "$sha"
        git -C "$dir" checkout --detach FETCH_HEAD --quiet
    fi

    local resolved
    resolved="$(git -C "$dir" rev-parse HEAD)"
    if [[ "$resolved" != "$sha" ]]; then
        error "Plugin '$name' HEAD $resolved does not match lock $sha"
        exit 1
    fi
    success "Installed $name@${sha:0:12}"
}

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"

section "Deploying symlinks..."
ensure_config_dir "$CONFIG_DIR/zsh"
migrate_secret "$DOTFILES_DIR/zsh/local.zsh" "$CONFIG_DIR/zsh/local.zsh"
link_file "$DOTFILES_DIR/zsh/.zshrc" "$CONFIG_DIR/zsh/.zshrc"
link_file "$DOTFILES_DIR/zsh/.zshenv" "$CONFIG_DIR/zsh/.zshenv"
link_file "$DOTFILES_DIR/zsh/config" "$CONFIG_DIR/zsh/config"
link_file "$DOTFILES_DIR/zsh/integrations" "$CONFIG_DIR/zsh/integrations"
link_file "$DOTFILES_DIR/zsh/.zshenv" "$HOME/.zshenv"

if [[ ! -f "$CONFIG_DIR/zsh/local.zsh" ]]; then
    cp "$DOTFILES_DIR/zsh/local.zsh.example" "$CONFIG_DIR/zsh/local.zsh"
    chmod 600 "$CONFIG_DIR/zsh/local.zsh"
    info "Initialized '$CONFIG_DIR/zsh/local.zsh' for local overrides"
fi

ensure_config_dir "$CONFIG_DIR/git"
migrate_secret "$DOTFILES_DIR/git/config.local" "$CONFIG_DIR/git/config.local"
link_file "$DOTFILES_DIR/git/config" "$CONFIG_DIR/git/config"
link_file "$DOTFILES_DIR/git/ignore" "$CONFIG_DIR/git/ignore"

link_file "$DOTFILES_DIR/mise/config.toml" "$CONFIG_DIR/mise/config.toml"
link_file "$DOTFILES_DIR/mise/mise.lock" "$CONFIG_DIR/mise/mise.lock"
link_file "$DOTFILES_DIR/tmux" "$CONFIG_DIR/tmux"
link_file "$DOTFILES_DIR/alacritty" "$CONFIG_DIR/alacritty"

section "Configuring SSH environment..."
SSH_DIR="$HOME/.ssh"
mkdir -p "$SSH_DIR/keys/personal" "$SSH_DIR/keys/work" "$SSH_DIR/keys/servers" "$SSH_DIR/sockets" "$SSH_DIR/conf.d"
chmod 700 "$SSH_DIR" "$SSH_DIR/keys" "$SSH_DIR/keys/personal" "$SSH_DIR/keys/work" "$SSH_DIR/keys/servers" "$SSH_DIR/sockets" "$SSH_DIR/conf.d"

link_file "$DOTFILES_DIR/ssh/config" "$SSH_DIR/config"
chmod 600 "$SSH_DIR/config"

if [[ ! -f "$SSH_DIR/config.local" ]]; then
    touch "$SSH_DIR/config.local"
    chmod 600 "$SSH_DIR/config.local"
    info "Initialized '$SSH_DIR/config.local' for local overrides"
else
    chmod 600 "$SSH_DIR/config.local"
fi

section "Setting up Zsh plugins..."
PLUGIN_DIR="$DATA_DIR/zsh/plugins"
mkdir -p "$PLUGIN_DIR"

if command -v git >/dev/null 2>&1; then
    while IFS= read -r plugin_name plugin_url plugin_sha _plugin_branch; do
        [[ -z "${plugin_name:-}" || "$plugin_name" == \#* ]] && continue
        install_plugin_at_sha "$plugin_name" "$plugin_url" "$plugin_sha"
    done <"$DOTFILES_DIR/locks/zsh-plugins.lock"
else
    warn "git not found; skipping Zsh plugin installation"
fi

section "Setting up Nerd Fonts..."
FONT_DIR=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    FONT_DIR="$HOME/Library/Fonts"
else
    FONT_DIR="$DATA_DIR/fonts"
fi

if find "$FONT_DIR" -maxdepth 1 -iname "*JetBrainsMono*Nerd*" 2>/dev/null | grep -q .; then
    info "JetBrainsMono Nerd Font already present"
else
    if command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
        info "Downloading JetBrainsMono Nerd Font ${LOCK_FONT_TAG}..."
        mkdir -p "$FONT_DIR"
        FONT_TEMP="$(mktemp -d)"
        FONT_ARCHIVE="$(mktemp)"
        FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${LOCK_FONT_TAG}/${LOCK_FONT_ASSET}"
        if curl -fsSL "$FONT_URL" -o "$FONT_ARCHIVE" \
            && verify_sha256 "$FONT_ARCHIVE" "$LOCK_FONT_SHA256" \
            && tar -xJ -f "$FONT_ARCHIVE" -C "$FONT_TEMP"; then
            find "$FONT_TEMP" -maxdepth 1 -type f \( -name "*.ttf" -o -name "*.otf" \) -exec cp {} "$FONT_DIR/" \;
            rm -rf "$FONT_TEMP" "$FONT_ARCHIVE"
            if command -v fc-cache >/dev/null 2>&1; then
                fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
            fi
            success "Installed JetBrainsMono Nerd Font ${LOCK_FONT_TAG}"
        else
            warn "Failed to download or verify JetBrainsMono Nerd Font; skipping"
            rm -rf "$FONT_TEMP" "$FONT_ARCHIVE"
        fi
    else
        warn "Missing 'curl' or 'tar'; skipping automatic font installation"
    fi
fi

section "Configuring Mise runtimes and tools..."
export PATH="$HOME/.local/bin:$PATH"
MISE_BIN="$(command -v mise 2>/dev/null || true)"
EXPECTED_MISE_VERSION="${LOCK_MISE_VERSION#v}"

install_pinned_mise=true
if [[ -n "$MISE_BIN" && -x "$MISE_BIN" ]]; then
    CURRENT_MISE_VERSION="$("$MISE_BIN" --version 2>/dev/null | awk '{print $1}')"
    if [[ "$CURRENT_MISE_VERSION" == "$EXPECTED_MISE_VERSION" ]]; then
        info "Mise ${EXPECTED_MISE_VERSION} already installed at $MISE_BIN"
        install_pinned_mise=false
    else
        info "Mise at $MISE_BIN is ${CURRENT_MISE_VERSION:-unknown}; installing pinned ${LOCK_MISE_VERSION}"
    fi
fi

if [[ "$install_pinned_mise" == true ]]; then
    if command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
        if MISE_TRIPLE="$(os_triple)"; then
            MISE_SHA="$(mise_sha256_for_triple "$MISE_TRIPLE")"
            if [[ -z "$MISE_SHA" ]]; then
                warn "No pinned checksum for Mise on $MISE_TRIPLE; skip bootstrap"
            else
                info "Downloading Mise ${LOCK_MISE_VERSION} ($MISE_TRIPLE)..."
                mkdir -p "$HOME/.local/bin"
                MISE_TEMP="$(mktemp -d)"
                MISE_ARCHIVE="$(mktemp)"
                MISE_URL="https://github.com/jdx/mise/releases/download/${LOCK_MISE_VERSION}/mise-${LOCK_MISE_VERSION}-${MISE_TRIPLE}.tar.gz"
                if curl -fsSL "$MISE_URL" -o "$MISE_ARCHIVE" \
                    && verify_sha256 "$MISE_ARCHIVE" "$MISE_SHA" \
                    && tar -xzf "$MISE_ARCHIVE" -C "$MISE_TEMP"; then
                    cp "$MISE_TEMP/mise/bin/mise" "$HOME/.local/bin/mise"
                    chmod 755 "$HOME/.local/bin/mise"
                    rm -rf "$MISE_TEMP" "$MISE_ARCHIVE"
                    MISE_BIN="$HOME/.local/bin/mise"
                    success "Mise ${LOCK_MISE_VERSION} installed to $MISE_BIN"
                else
                    warn "Failed to download or verify Mise; skipping"
                    rm -rf "$MISE_TEMP" "$MISE_ARCHIVE"
                    MISE_BIN="$(command -v mise 2>/dev/null || true)"
                fi
            fi
        else
            warn "Unsupported platform for pinned Mise bootstrap"
        fi
    else
        warn "Missing 'curl' or 'tar'; please install Mise manually: https://mise.jdx.dev"
    fi
fi

if [[ -n "$MISE_BIN" && -x "$MISE_BIN" ]]; then
    info "Provisioning declared tools via Mise (locked)..."
    if MISE_LOCKED=1 "$MISE_BIN" install --locked; then
        success "All Mise tools provisioned successfully"
    else
        warn "Mise tool provisioning encountered errors. Run 'mise install --locked' to inspect."
    fi
fi

section "Configuring default login shell..."
ZSH_PATH="$(command -v zsh 2>/dev/null || true)"

if [[ -z "$ZSH_PATH" ]]; then
    warn "Zsh executable not found in PATH; please install Zsh manually"
else
    CURRENT_USER="${USER:-$(whoami 2>/dev/null || echo "$LOGNAME")}"
    CURRENT_SHELL=""
    if command -v getent >/dev/null 2>&1; then
        CURRENT_SHELL="$(getent passwd "$CURRENT_USER" 2>/dev/null | cut -d: -f7 || true)"
    fi
    [[ -z "$CURRENT_SHELL" ]] && CURRENT_SHELL="${SHELL:-}"

    if [[ "$CURRENT_SHELL" != "$ZSH_PATH" ]]; then
        info "Updating login shell to $ZSH_PATH..."
        if command -v chsh >/dev/null 2>&1; then
            if chsh -s "$ZSH_PATH"; then
                success "Default shell updated to $ZSH_PATH"
            else
                warn "Failed to change shell automatically. Run: chsh -s $ZSH_PATH"
            fi
        else
            warn "'chsh' utility not found; update login shell manually"
        fi
    else
        info "Zsh is already the default login shell ($ZSH_PATH)"
    fi
fi

section "Verifying terminal emulator..."
if command -v alacritty >/dev/null 2>&1; then
    ALACRITTY_VER="$(alacritty --version 2>/dev/null | head -n1 || echo 'detected')"
    success "Alacritty is installed ($ALACRITTY_VER)"
else
    info "Alacritty is not installed (config deployed to $CONFIG_DIR/alacritty)"
fi

# ==============================================================================
# Interactive Setup: Backup Restoration, Git Identity & Personal SSH Key
# ==============================================================================
section "Checking for existing backup archive..."
if [[ -t 0 ]]; then
    read -r -p "  Do you have an existing backup archive to restore? [y/N]: " has_backup_choice
    if [[ "$has_backup_choice" =~ ^[Yy]$ ]]; then
        read -r -p "  Enter path to backup archive (e.g. ~/dotfiles-backup.tar.gz): " backup_archive_path
        if [[ -n "$backup_archive_path" ]]; then
            expanded_backup="${backup_archive_path/#\~/$HOME}"
            if [[ -f "$expanded_backup" ]]; then
                "$DOTFILES_DIR/restore.sh" "$expanded_backup"
            else
                warn "Backup archive not found at '$backup_archive_path'; continuing with standard setup"
            fi
        fi
    fi
fi

section "Configuring Git identity..."
GIT_CONFIG_LOCAL="$CONFIG_DIR/git/config.local"
GIT_NAME=""
GIT_EMAIL=""

if [[ -f "$GIT_CONFIG_LOCAL" ]]; then
    CURRENT_GIT_NAME="$(git config --file "$GIT_CONFIG_LOCAL" user.name 2>/dev/null || true)"
    CURRENT_GIT_EMAIL="$(git config --file "$GIT_CONFIG_LOCAL" user.email 2>/dev/null || true)"
    if [[ -n "$CURRENT_GIT_NAME" && -n "$CURRENT_GIT_EMAIL" ]]; then
        info "Current Git identity: $CURRENT_GIT_NAME <$CURRENT_GIT_EMAIL>"
        if [[ -t 0 ]]; then
            read -r -p "  Do you want to update this identity? [y/N]: " update_git_identity
            if [[ "$update_git_identity" =~ ^[Yy]$ ]]; then
                read -r -p "  Enter Git author name [$CURRENT_GIT_NAME]: " input_name
                read -r -p "  Enter Git author email [$CURRENT_GIT_EMAIL]: " input_email
                GIT_NAME="${input_name:-$CURRENT_GIT_NAME}"
                GIT_EMAIL="${input_email:-$CURRENT_GIT_EMAIL}"
            else
                GIT_NAME="$CURRENT_GIT_NAME"
                GIT_EMAIL="$CURRENT_GIT_EMAIL"
            fi
        else
            GIT_NAME="$CURRENT_GIT_NAME"
            GIT_EMAIL="$CURRENT_GIT_EMAIL"
        fi
    fi
fi

if [[ -z "$GIT_NAME" || -z "$GIT_EMAIL" ]]; then
    if [[ -t 0 ]]; then
        info "Configuring local Git identity (saved to $GIT_CONFIG_LOCAL)"
        read -r -p "  Enter Git author name: " GIT_NAME
        read -r -p "  Enter Git author email: " GIT_EMAIL
    fi
fi

if [[ -n "${GIT_NAME:-}" && -n "${GIT_EMAIL:-}" ]]; then
    touch "$GIT_CONFIG_LOCAL"
    chmod 600 "$GIT_CONFIG_LOCAL"
    git config --file "$GIT_CONFIG_LOCAL" user.name "$GIT_NAME"
    git config --file "$GIT_CONFIG_LOCAL" user.email "$GIT_EMAIL"
    chmod 600 "$GIT_CONFIG_LOCAL"
    success "Configured Git identity: $GIT_NAME <$GIT_EMAIL>"
else
    if [[ ! -f "$GIT_CONFIG_LOCAL" ]]; then
        cp "$DOTFILES_DIR/git/config.local.example" "$GIT_CONFIG_LOCAL"
        chmod 600 "$GIT_CONFIG_LOCAL"
        warn "Git identity skipped. Template created at '$GIT_CONFIG_LOCAL'"
    fi
fi

section "Configuring personal SSH keypair..."
PERSONAL_KEY="$HOME/.ssh/keys/personal/id_ed25519"

if [[ -f "$PERSONAL_KEY" ]]; then
    info "Personal SSH key already exists at '$PERSONAL_KEY'"
else
    if [[ -t 0 ]]; then
        echo "  Would you like to generate a new personal SSH key (ed25519) now?"
        read -r -p "  Generate personal key? (Skip if you already have existing keys or backup) [y/N]: " gen_key_choice
        if [[ "$gen_key_choice" =~ ^[Yy]$ ]]; then
            KEY_COMMENT="${GIT_EMAIL:-${USER:-$(whoami)}}"
            info "Generating ed25519 key at '$PERSONAL_KEY'..."
            ssh-keygen -t ed25519 -C "$KEY_COMMENT" -f "$PERSONAL_KEY"
            chmod 600 "$PERSONAL_KEY"
            chmod 644 "${PERSONAL_KEY}.pub"
            success "Personal SSH key generated at '$PERSONAL_KEY'"

            if command -v wl-copy >/dev/null 2>&1; then
                wl-copy <"${PERSONAL_KEY}.pub"
                info "Public key copied to clipboard via wl-copy"
            elif command -v xclip >/dev/null 2>&1; then
                xclip -selection clipboard <"${PERSONAL_KEY}.pub"
                info "Public key copied to clipboard via xclip"
            elif command -v pbcopy >/dev/null 2>&1; then
                pbcopy <"${PERSONAL_KEY}.pub"
                info "Public key copied to clipboard via pbcopy"
            fi
        else
            info "Skipped key generation. You can import existing keys with 'ssh-import' or generate later with 'ssh-new'."
        fi
    else
        info "Non-interactive environment; skipping SSH key generation prompt"
    fi
fi

# ==============================================================================
# Final Post-Installation Summary
# ==============================================================================
printf "\n%b=== Installation Summary ===%b\n" "${BOLD}${BLUE}" "$NC"
if [[ -n "${GIT_NAME:-}" && -n "${GIT_EMAIL:-}" ]]; then
    printf "  %b•%b Git Identity : %s <%s>\n" "$CYAN" "$NC" "$GIT_NAME" "$GIT_EMAIL"
else
    printf "  %b•%b Git Identity : %s\n" "$YELLOW" "$NC" "Template at ~/.config/git/config.local"
fi

if [[ -f "$PERSONAL_KEY" ]]; then
    printf "  %b•%b Personal SSH : %s\n" "$GREEN" "$NC" "$PERSONAL_KEY"
else
    printf "  %b•%b Personal SSH : %s\n" "$YELLOW" "$NC" "Not generated (run 'ssh-new' or 'ssh-import')"
fi

printf "  %b•%b Default Shell: %s\n" "$CYAN" "$NC" "${ZSH_PATH:-zsh}"

printf "\n%bInstallation completed successfully.%b\n\n" "${BOLD}${GREEN}" "$NC"
