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

install_configs() {
    section "Configs"
    ensure_config_dir "$CONFIG_DIR/zsh" "$DOTFILES_DIR/zsh"
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

    ensure_config_dir "$CONFIG_DIR/git" "$DOTFILES_DIR/git"
    migrate_secret "$DOTFILES_DIR/git/config.local" "$CONFIG_DIR/git/config.local"
    link_file "$DOTFILES_DIR/git/config" "$CONFIG_DIR/git/config"
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
    chmod 600 "$ssh_dir/config"

    if [[ ! -f "$ssh_dir/config.local" ]]; then
        touch "$ssh_dir/config.local"
        chmod 600 "$ssh_dir/config.local"
        info "Created $ssh_dir/config.local for host overrides"
    else
        chmod 600 "$ssh_dir/config.local"
    fi
}
