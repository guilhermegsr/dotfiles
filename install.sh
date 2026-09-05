#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$DOTFILES_DIR/scripts/lib.sh"
# shellcheck source=scripts/lock-utils.sh
source "$DOTFILES_DIR/scripts/lock-utils.sh"

load_bootstrap_lock "$DOTFILES_DIR/locks/bootstrap.lock"

printf "\n%b=== Install ===%b\n" "${BOLD}${BLUE}" "$NC"
printf "%bSource: %s%b\n" "$DIM" "$DOTFILES_DIR" "$NC"

# Legacy installs symlinked the whole dir; secrets must live outside the repo.
ensure_config_dir() {
    local dest="$1"
    if [[ -L "$dest" ]]; then
        warn "Replacing directory symlink $dest with a real directory"
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
        info "Moved $src to $dest"
    fi
}

install_plugin_at_sha() {
    local name="$1"
    local url="$2"
    local sha="$3"
    local dir="$PLUGIN_DIR/$name"

    if [[ ! "$sha" =~ ^[0-9a-f]{7,40}$ ]]; then
        error "Invalid plugin SHA for $name: $sha"
        exit 1
    fi

    if [[ -d "$dir/.git" ]]; then
        local current
        current="$(git -C "$dir" rev-parse HEAD)"
        if [[ "$current" == "$sha" ]]; then
            info "$name is already at ${sha:0:12}"
            return 0
        fi
        info "Updating $name to ${sha:0:12}"
        git -C "$dir" fetch --depth 1 origin "$sha"
        git -C "$dir" checkout --detach "$sha"
    else
        rm -rf "$dir"
        mkdir -p "$dir"
        info "Cloning $name at ${sha:0:12}"
        git -C "$dir" init --quiet
        git -C "$dir" remote add origin "$url"
        git -C "$dir" fetch --depth 1 origin "$sha"
        git -C "$dir" checkout --detach FETCH_HEAD --quiet
    fi

    local resolved
    resolved="$(git -C "$dir" rev-parse HEAD)"
    if [[ "$resolved" != "$sha" ]]; then
        error "Plugin $name is at $resolved, expected $sha"
        exit 1
    fi
    success "Installed $name at ${sha:0:12}"
}

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"

section "Configs"
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
    info "Created $CONFIG_DIR/zsh/local.zsh for local overrides"
fi

ensure_config_dir "$CONFIG_DIR/git"
migrate_secret "$DOTFILES_DIR/git/config.local" "$CONFIG_DIR/git/config.local"
link_file "$DOTFILES_DIR/git/config" "$CONFIG_DIR/git/config"
link_file "$DOTFILES_DIR/git/ignore" "$CONFIG_DIR/git/ignore"

link_file "$DOTFILES_DIR/mise/config.toml" "$CONFIG_DIR/mise/config.toml"
link_file "$DOTFILES_DIR/mise/mise.lock" "$CONFIG_DIR/mise/mise.lock"
link_file "$DOTFILES_DIR/tmux" "$CONFIG_DIR/tmux"
link_file "$DOTFILES_DIR/alacritty" "$CONFIG_DIR/alacritty"

section "SSH"
SSH_DIR="$HOME/.ssh"
mkdir -p "$SSH_DIR/keys/personal" "$SSH_DIR/keys/work" "$SSH_DIR/keys/servers" "$SSH_DIR/sockets" "$SSH_DIR/conf.d"
chmod 700 "$SSH_DIR" "$SSH_DIR/keys" "$SSH_DIR/keys/personal" "$SSH_DIR/keys/work" "$SSH_DIR/keys/servers" "$SSH_DIR/sockets" "$SSH_DIR/conf.d"

link_file "$DOTFILES_DIR/ssh/config" "$SSH_DIR/config"
chmod 600 "$SSH_DIR/config"

if [[ ! -f "$SSH_DIR/config.local" ]]; then
    touch "$SSH_DIR/config.local"
    chmod 600 "$SSH_DIR/config.local"
    info "Created $SSH_DIR/config.local for host overrides"
else
    chmod 600 "$SSH_DIR/config.local"
fi

section "Plugins"
PLUGIN_DIR="$DATA_DIR/zsh/plugins"
mkdir -p "$PLUGIN_DIR"

if command -v git >/dev/null 2>&1; then
    while read -r plugin_name plugin_url plugin_sha _plugin_branch; do
        [[ -z "${plugin_name:-}" || "$plugin_name" == \#* ]] && continue
        install_plugin_at_sha "$plugin_name" "$plugin_url" "$plugin_sha"
    done <"$DOTFILES_DIR/locks/zsh-plugins.lock"
else
    warn "git was not found; skipping Zsh plugins"
fi

section "Fonts"
FONT_DIR=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    FONT_DIR="$HOME/Library/Fonts"
else
    FONT_DIR="$DATA_DIR/fonts"
fi

if find "$FONT_DIR" -maxdepth 1 -iname "*JetBrainsMono*Nerd*" 2>/dev/null | grep -q .; then
    info "JetBrainsMono Nerd Font already installed"
else
    if command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
        info "Downloading JetBrainsMono Nerd Font ${LOCK_FONT_TAG}"
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
            warn "Could not download or verify the font; skipping"
            rm -rf "$FONT_TEMP" "$FONT_ARCHIVE"
        fi
    else
        warn "curl and tar are required to install fonts"
    fi
fi

section "Mise"
export PATH="$HOME/.local/bin:$PATH"
MISE_BIN="$(command -v mise 2>/dev/null || true)"
EXPECTED_MISE_VERSION="${LOCK_MISE_VERSION#v}"

install_pinned_mise=true
if [[ -n "$MISE_BIN" && -x "$MISE_BIN" ]]; then
    CURRENT_MISE_VERSION="$("$MISE_BIN" --version 2>/dev/null | awk '{print $1}')"
    if [[ "$CURRENT_MISE_VERSION" == "$EXPECTED_MISE_VERSION" ]]; then
        info "Mise ${EXPECTED_MISE_VERSION} is already installed at $MISE_BIN"
        install_pinned_mise=false
    else
        info "Found Mise ${CURRENT_MISE_VERSION:-unknown} at $MISE_BIN; installing ${LOCK_MISE_VERSION}"
    fi
fi

if [[ "$install_pinned_mise" == true ]]; then
    if command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
        if MISE_TRIPLE="$(os_triple)"; then
            MISE_SHA="$(mise_sha256_for_triple "$MISE_TRIPLE")"
            if [[ -z "$MISE_SHA" ]]; then
                warn "No pinned checksum for Mise on $MISE_TRIPLE"
            else
                info "Downloading Mise ${LOCK_MISE_VERSION} $MISE_TRIPLE"
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
                    success "Installed Mise ${LOCK_MISE_VERSION} to $MISE_BIN"
                else
                    warn "Could not download or verify Mise; skipping"
                    rm -rf "$MISE_TEMP" "$MISE_ARCHIVE"
                    MISE_BIN="$(command -v mise 2>/dev/null || true)"
                fi
            fi
        else
            warn "This platform is not supported for the pinned Mise install"
        fi
    else
        warn "curl and tar are required to install Mise. See https://mise.jdx.dev"
    fi
fi

if [[ -n "$MISE_BIN" && -x "$MISE_BIN" ]]; then
    info "Installing tools declared in Mise"
    if MISE_LOCKED=1 "$MISE_BIN" install --locked; then
        success "Mise tools installed"
    else
        warn "Mise tool installation failed. Run 'mise install --locked' to inspect."
    fi
fi

section "Login shell"
ZSH_PATH="$(command -v zsh 2>/dev/null || true)"

if [[ -z "$ZSH_PATH" ]]; then
    warn "zsh was not found in PATH"
else
    CURRENT_USER="${USER:-$(whoami 2>/dev/null || echo "$LOGNAME")}"
    CURRENT_SHELL=""
    if command -v getent >/dev/null 2>&1; then
        CURRENT_SHELL="$(getent passwd "$CURRENT_USER" 2>/dev/null | cut -d: -f7 || true)"
    fi
    [[ -z "$CURRENT_SHELL" ]] && CURRENT_SHELL="${SHELL:-}"

    if [[ "$CURRENT_SHELL" != "$ZSH_PATH" ]]; then
        info "Setting login shell to $ZSH_PATH"
        previous_shell_file="$(dotfiles_previous_shell_file)"
        mkdir -p "$(dirname "$previous_shell_file")"
        if [[ ! -f "$previous_shell_file" && -n "$CURRENT_SHELL" ]]; then
            printf '%s\n' "$CURRENT_SHELL" >"$previous_shell_file"
            chmod 600 "$previous_shell_file"
        fi
        if [[ "${DOTFILES_SKIP_CHSH:-}" == 1 ]]; then
            info "Skipping chsh; would switch to $ZSH_PATH"
        elif command -v chsh >/dev/null 2>&1; then
            if chsh -s "$ZSH_PATH"; then
                success "Login shell set to $ZSH_PATH"
            else
                warn "Could not change the login shell. Run: chsh -s $ZSH_PATH"
            fi
        else
            warn "chsh was not found; set the login shell manually"
        fi
    else
        info "Login shell is already $ZSH_PATH"
    fi
fi

section "Terminal"
if command -v alacritty >/dev/null 2>&1; then
    ALACRITTY_VER="$(alacritty --version 2>/dev/null | head -n1 || echo 'detected')"
    success "Alacritty $ALACRITTY_VER"
else
    info "Alacritty is not installed; config deployed to $CONFIG_DIR/alacritty"
fi

section "Backup"
if [[ -t 0 ]]; then
    read -r -p "  Restore an existing backup archive? [y/N]: " has_backup_choice
    if [[ "$has_backup_choice" =~ ^[Yy]$ ]]; then
        read -r -p "  Archive path: " backup_archive_path
        if [[ -n "$backup_archive_path" ]]; then
            expanded_backup="${backup_archive_path/#\~/$HOME}"
            if [[ -f "$expanded_backup" ]]; then
                "$DOTFILES_DIR/restore.sh" "$expanded_backup"
            else
                warn "Backup archive not found: $backup_archive_path"
            fi
        fi
    fi
fi

section "Git identity"
GIT_CONFIG_LOCAL="$CONFIG_DIR/git/config.local"
GIT_NAME=""
GIT_EMAIL=""

if [[ -f "$GIT_CONFIG_LOCAL" ]]; then
    CURRENT_GIT_NAME="$(git config --file "$GIT_CONFIG_LOCAL" user.name 2>/dev/null || true)"
    CURRENT_GIT_EMAIL="$(git config --file "$GIT_CONFIG_LOCAL" user.email 2>/dev/null || true)"
    if [[ -n "$CURRENT_GIT_NAME" && -n "$CURRENT_GIT_EMAIL" ]]; then
        info "Git identity: $CURRENT_GIT_NAME <$CURRENT_GIT_EMAIL>"
        if [[ -t 0 ]]; then
            read -r -p "  Update this identity? [y/N]: " update_git_identity
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
        info "Saving Git identity to $GIT_CONFIG_LOCAL"
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
    success "Git identity: $GIT_NAME <$GIT_EMAIL>"
else
    if [[ ! -f "$GIT_CONFIG_LOCAL" ]]; then
        cp "$DOTFILES_DIR/git/config.local.example" "$GIT_CONFIG_LOCAL"
        chmod 600 "$GIT_CONFIG_LOCAL"
        warn "Git identity skipped. A template was written to $GIT_CONFIG_LOCAL"
    fi
fi

section "SSH key"
PERSONAL_KEY="$HOME/.ssh/keys/personal/id_ed25519"

if [[ -f "$PERSONAL_KEY" ]]; then
    info "Personal SSH key already exists at $PERSONAL_KEY"
else
    if [[ -t 0 ]]; then
        read -r -p "  Generate a personal ed25519 key? [y/N]: " gen_key_choice
        if [[ "$gen_key_choice" =~ ^[Yy]$ ]]; then
            KEY_COMMENT="${GIT_EMAIL:-${USER:-$(whoami)}}"
            info "Generating key at $PERSONAL_KEY"
            ssh-keygen -t ed25519 -C "$KEY_COMMENT" -f "$PERSONAL_KEY"
            chmod 600 "$PERSONAL_KEY"
            chmod 644 "${PERSONAL_KEY}.pub"
            success "Created personal key at $PERSONAL_KEY"

            if command -v wl-copy >/dev/null 2>&1; then
                wl-copy <"${PERSONAL_KEY}.pub"
                info "Public key copied via wl-copy"
            elif command -v xclip >/dev/null 2>&1; then
                xclip -selection clipboard <"${PERSONAL_KEY}.pub"
                info "Public key copied via xclip"
            elif command -v pbcopy >/dev/null 2>&1; then
                pbcopy <"${PERSONAL_KEY}.pub"
                info "Public key copied via pbcopy"
            fi
        else
            info "Skipped key generation. You can run ssh-new or ssh-import later."
        fi
    else
        info "Non-interactive session; skipping SSH key generation"
    fi
fi

printf "\n%b=== Summary ===%b\n" "${BOLD}${BLUE}" "$NC"
if [[ -n "${GIT_NAME:-}" && -n "${GIT_EMAIL:-}" ]]; then
    printf "  %b•%b Git: %s <%s>\n" "$CYAN" "$NC" "$GIT_NAME" "$GIT_EMAIL"
else
    printf "  %b•%b Git: template at ~/.config/git/config.local\n" "$YELLOW" "$NC"
fi

if [[ -f "$PERSONAL_KEY" ]]; then
    printf "  %b•%b SSH: %s\n" "$GREEN" "$NC" "$PERSONAL_KEY"
else
    printf "  %b•%b SSH: not generated. Run ssh-new or ssh-import.\n" "$YELLOW" "$NC"
fi

printf "  %b•%b Shell: %s\n" "$CYAN" "$NC" "${ZSH_PATH:-zsh}"

printf "\n%bInstall complete.%b\n\n" "${BOLD}${GREEN}" "$NC"
