# shellcheck shell=bash
# Legacy installs symlinked whole config directories; secrets must remain outside the repo.
ensure_config_dir() {
    local dest="$1"
    local legacy_target="${2:-}"

    if [[ -L "$dest" ]]; then
        local current_target
        current_target="$(readlink "$dest")"
        if [[ -n "$legacy_target" && "$current_target" == "$legacy_target" ]]; then
            warn "Migrating legacy directory symlink $dest to a real directory"
            rm "$dest"
        else
            error "Refusing to replace directory symlink $dest -> $current_target"
            error "Move it aside explicitly, then run the installer again."
            return 1
        fi
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

# A real file, not a symlink: `git config --global` must not write into the repo.
install_git_global_config() {
    local global="$CONFIG_DIR/git/config"
    local shared="$DOTFILES_DIR/git/config"

    if [[ -L "$global" ]]; then
        local current_target
        current_target="$(readlink "$global")"
        if [[ "$current_target" == "$shared" ]]; then
            warn "Migrating legacy symlink $global to a machine-local file"
            rm "$global"
        else
            error "Refusing to replace symlink $global -> $current_target"
            error "Move it aside explicitly, then run the installer again."
            return 1
        fi
    fi

    if [[ ! -e "$global" ]]; then
        cat >"$global" <<EOF
# Machine-local Git config written by the dotfiles installer.
# Shared settings live in $shared; \`git config --global\` writes land here.
[include]
    path = $shared
[include]
    path = config.local
EOF
        success "Created $global including $shared"
        return 0
    fi

    local want
    for want in "$shared" "config.local"; do
        if git config --file "$global" --get-all include.path 2>/dev/null | grep -qxF "$want"; then
            continue
        fi
        git config --file "$global" --add include.path "$want"
        info "Added include.path=$want to $global"
    done
    success "Global Git config includes $shared"
}

install_configs() {
    section "Configs"
    ensure_config_dir "$CONFIG_DIR/zsh" "$DOTFILES_DIR/zsh"
    migrate_secret "$DOTFILES_DIR/zsh/local.zsh" "$CONFIG_DIR/zsh/local.zsh"
    link_file "$DOTFILES_DIR/zsh/.zshrc" "$CONFIG_DIR/zsh/.zshrc"
    link_file "$DOTFILES_DIR/zsh/.zshenv" "$CONFIG_DIR/zsh/.zshenv"
    link_file "$DOTFILES_DIR/zsh/config" "$CONFIG_DIR/zsh/config"
    link_file "$DOTFILES_DIR/zsh/integrations" "$CONFIG_DIR/zsh/integrations"
    link_file "$DOTFILES_DIR/zsh/.zshenv" "$HOME/.zshenv"

    # ZDOTDIR now points elsewhere, so this file is never read again.
    if [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
        warn "$HOME/.zshrc is no longer read; the shell now loads $CONFIG_DIR/zsh/.zshrc"
        warn "Move anything you still want into $CONFIG_DIR/zsh/local.zsh"
    fi

    if [[ ! -f "$CONFIG_DIR/zsh/local.zsh" ]]; then
        cp "$DOTFILES_DIR/zsh/local.zsh.example" "$CONFIG_DIR/zsh/local.zsh"
        chmod 600 "$CONFIG_DIR/zsh/local.zsh"
        info "Created $CONFIG_DIR/zsh/local.zsh for local overrides"
    fi

    ensure_config_dir "$CONFIG_DIR/git" "$DOTFILES_DIR/git"
    migrate_secret "$DOTFILES_DIR/git/config.local" "$CONFIG_DIR/git/config.local"
    install_git_global_config
    link_file "$DOTFILES_DIR/git/ignore" "$CONFIG_DIR/git/ignore"

    link_file "$DOTFILES_DIR/mise/config.toml" "$CONFIG_DIR/mise/config.toml"
    link_file "$DOTFILES_DIR/starship/starship.toml" "$CONFIG_DIR/starship.toml"
    link_file "$DOTFILES_DIR/tmux" "$CONFIG_DIR/tmux"
    link_file "$DOTFILES_DIR/alacritty" "$CONFIG_DIR/alacritty"
}

install_ssh_config() {
    section "SSH"
    local ssh_dir="$HOME/.ssh"

    mkdir -p "$ssh_dir/keys/personal" "$ssh_dir/keys/work" "$ssh_dir/keys/servers" "$ssh_dir/sockets" "$ssh_dir/conf.d"
    chmod 700 "$ssh_dir" "$ssh_dir/keys" "$ssh_dir/keys/personal" "$ssh_dir/keys/work" "$ssh_dir/keys/servers" "$ssh_dir/sockets" "$ssh_dir/conf.d"

    link_file "$DOTFILES_DIR/ssh/config" "$ssh_dir/config"
    # chmod would follow the symlink into the repository. OpenSSH only asks
    # that the config not be world-writable, which a checkout already satisfies.
    if [[ ! -L "$ssh_dir/config" ]]; then
        chmod 600 "$ssh_dir/config"
    fi

    if [[ ! -f "$ssh_dir/config.local" ]]; then
        touch "$ssh_dir/config.local"
        chmod 600 "$ssh_dir/config.local"
        info "Created $ssh_dir/config.local for host overrides"
    else
        chmod 600 "$ssh_dir/config.local"
    fi
}
