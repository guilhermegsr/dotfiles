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

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"

section "Deploying symlinks..."
link_file "$DOTFILES_DIR/zsh" "$CONFIG_DIR/zsh"
link_file "$DOTFILES_DIR/zsh/.zshenv" "$HOME/.zshenv"
link_file "$DOTFILES_DIR/git" "$CONFIG_DIR/git"
link_file "$DOTFILES_DIR/mise/config.toml" "$CONFIG_DIR/mise/config.toml"
link_file "$DOTFILES_DIR/tmux" "$CONFIG_DIR/tmux"
link_file "$DOTFILES_DIR/alacritty" "$CONFIG_DIR/alacritty"

section "Configuring SSH environment..."
SSH_DIR="$HOME/.ssh"
mkdir -p "$SSH_DIR/keys/personal" "$SSH_DIR/keys/work" "$SSH_DIR/keys/servers" "$SSH_DIR/sockets"
chmod 700 "$SSH_DIR" "$SSH_DIR/keys" "$SSH_DIR/keys/personal" "$SSH_DIR/keys/work" "$SSH_DIR/keys/servers" "$SSH_DIR/sockets" 2>/dev/null || true

link_file "$DOTFILES_DIR/ssh/config" "$SSH_DIR/config"
chmod 600 "$DOTFILES_DIR/ssh/config" 2>/dev/null || true

if [[ ! -f "$SSH_DIR/config.local" ]]; then
    touch "$SSH_DIR/config.local"
    chmod 600 "$SSH_DIR/config.local"
    info "Initialized '$SSH_DIR/config.local' for local overrides"
fi

section "Setting up Zsh plugins..."
PLUGIN_DIR="$DATA_DIR/zsh/plugins"
mkdir -p "$PLUGIN_DIR"

if [[ ! -d "$PLUGIN_DIR/zsh-autosuggestions" ]]; then
    if command -v git >/dev/null 2>&1; then
        info "Cloning zsh-autosuggestions..."
        git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions "$PLUGIN_DIR/zsh-autosuggestions"
        success "Installed zsh-autosuggestions"
    fi
else
    info "zsh-autosuggestions already installed"
fi

if [[ ! -d "$PLUGIN_DIR/zsh-syntax-highlighting" ]]; then
    if command -v git >/dev/null 2>&1; then
        info "Cloning zsh-syntax-highlighting..."
        git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting "$PLUGIN_DIR/zsh-syntax-highlighting"
        success "Installed zsh-syntax-highlighting"
    fi
else
    info "zsh-syntax-highlighting already installed"
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
        info "Downloading JetBrainsMono Nerd Font..."
        mkdir -p "$FONT_DIR"
        FONT_TEMP="$(mktemp -d)"
        FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"
        if curl -fsSL "$FONT_URL" | tar -xJ -C "$FONT_TEMP" 2>/dev/null; then
            find "$FONT_TEMP" -maxdepth 1 -type f \( -name "*.ttf" -o -name "*.otf" \) -exec cp {} "$FONT_DIR/" \;
            rm -rf "$FONT_TEMP"
            if command -v fc-cache >/dev/null 2>&1; then
                fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
            fi
            success "Installed JetBrainsMono Nerd Font"
        else
            warn "Failed to download JetBrainsMono Nerd Font; skipping"
            rm -rf "$FONT_TEMP"
        fi
    else
        warn "Missing 'curl' or 'tar'; skipping automatic font installation"
    fi
fi

section "Configuring Mise runtimes and tools..."
export PATH="$HOME/.local/bin:$PATH"
MISE_BIN="$(command -v mise 2>/dev/null || true)"

if [[ -z "$MISE_BIN" ]]; then
    if command -v curl >/dev/null 2>&1; then
        info "Bootstrapping Mise CLI..."
        curl -fsSL https://mise.run | sh
        MISE_BIN="$HOME/.local/bin/mise"
        success "Mise installed to $MISE_BIN"
    else
        warn "Missing 'curl'; please install Mise manually: https://mise.jdx.dev"
    fi
else
    info "Mise detected at $MISE_BIN"
fi

if [[ -n "$MISE_BIN" && -x "$MISE_BIN" ]]; then
    info "Provisioning declared tools via Mise..."
    if "$MISE_BIN" install; then
        success "All Mise tools provisioned successfully"
    else
        warn "Mise tool provisioning encountered errors. Run 'mise install' to inspect."
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
        info "Configuring local Git identity (saved to ~/.config/git/config.local)"
        read -r -p "  Enter Git author name: " GIT_NAME
        read -r -p "  Enter Git author email: " GIT_EMAIL
    fi
fi

if [[ -n "${GIT_NAME:-}" && -n "${GIT_EMAIL:-}" ]]; then
    cat > "$GIT_CONFIG_LOCAL" <<EOF
[user]
    name = $GIT_NAME
    email = $GIT_EMAIL
EOF
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
                wl-copy < "${PERSONAL_KEY}.pub"
                info "Public key copied to clipboard via wl-copy"
            elif command -v xclip >/dev/null 2>&1; then
                xclip -selection clipboard < "${PERSONAL_KEY}.pub"
                info "Public key copied to clipboard via xclip"
            elif command -v pbcopy >/dev/null 2>&1; then
                pbcopy < "${PERSONAL_KEY}.pub"
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