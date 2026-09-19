# shellcheck shell=bash
offer_backup_restore() {
    section "Backup"
    if [[ ! -t 0 ]]; then
        return 0
    fi

    local has_backup_choice backup_archive_path expanded_backup
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
}

configure_git_identity() {
    section "Git identity"
    local git_config_local="$CONFIG_DIR/git/config.local"
    local current_git_name="" current_git_email=""
    GIT_NAME=""
    GIT_EMAIL=""

    if [[ -f "$git_config_local" ]]; then
        current_git_name="$(git config --file "$git_config_local" user.name 2>/dev/null || true)"
        current_git_email="$(git config --file "$git_config_local" user.email 2>/dev/null || true)"
        if [[ -n "$current_git_name" && -n "$current_git_email" ]]; then
            info "Git identity: $current_git_name <$current_git_email>"
            if [[ -t 0 ]]; then
                local update_git_identity input_name input_email
                read -r -p "  Update this identity? [y/N]: " update_git_identity
                if [[ "$update_git_identity" =~ ^[Yy]$ ]]; then
                    read -r -p "  Enter Git author name [$current_git_name]: " input_name
                    read -r -p "  Enter Git author email [$current_git_email]: " input_email
                    GIT_NAME="${input_name:-$current_git_name}"
                    GIT_EMAIL="${input_email:-$current_git_email}"
                else
                    GIT_NAME="$current_git_name"
                    GIT_EMAIL="$current_git_email"
                fi
            else
                GIT_NAME="$current_git_name"
                GIT_EMAIL="$current_git_email"
            fi
        fi
    fi

    if [[ -z "$GIT_NAME" || -z "$GIT_EMAIL" ]] && [[ -t 0 ]]; then
        info "Saving Git identity to $git_config_local"
        read -r -p "  Enter Git author name: " GIT_NAME
        read -r -p "  Enter Git author email: " GIT_EMAIL
    fi

    if [[ -n "$GIT_NAME" && -n "$GIT_EMAIL" ]]; then
        touch "$git_config_local"
        chmod 600 "$git_config_local"
        git config --file "$git_config_local" user.name "$GIT_NAME"
        git config --file "$git_config_local" user.email "$GIT_EMAIL"
        chmod 600 "$git_config_local"
        success "Git identity: $GIT_NAME <$GIT_EMAIL>"
    elif [[ ! -f "$git_config_local" ]]; then
        cp "$DOTFILES_DIR/git/config.local.example" "$git_config_local"
        chmod 600 "$git_config_local"
        warn "Git identity skipped. A template was written to $git_config_local"
    fi
}

configure_ssh_key() {
    section "SSH key"
    PERSONAL_KEY="$HOME/.ssh/keys/personal/id_ed25519"

    if [[ -f "$PERSONAL_KEY" ]]; then
        info "Personal SSH key already exists at $PERSONAL_KEY"
        return 0
    fi
    if [[ ! -t 0 ]]; then
        info "Non-interactive session; skipping SSH key generation"
        return 0
    fi

    local gen_key_choice
    read -r -p "  Generate a personal ed25519 key? [y/N]: " gen_key_choice
    if [[ ! "$gen_key_choice" =~ ^[Yy]$ ]]; then
        info "Skipped key generation. You can run ssh-new or ssh-import later."
        return 0
    fi

    local key_comment
    key_comment="${GIT_EMAIL:-${USER:-dotfiles}}"
    info "Generating key at $PERSONAL_KEY"
    ssh-keygen -t ed25519 -C "$key_comment" -f "$PERSONAL_KEY"
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
}

print_install_summary() {
    printf "\n%b=== Summary ===%b\n" "${BOLD}${BLUE}" "$NC"
    if [[ -n "${GIT_NAME:-}" && -n "${GIT_EMAIL:-}" ]]; then
        printf "  %b•%b Git: %s <%s>\n" "$CYAN" "$NC" "$GIT_NAME" "$GIT_EMAIL"
    else
        printf "  %b•%b Git: template at ~/.config/git/config.local\n" "$YELLOW" "$NC"
    fi

    if [[ -f "${PERSONAL_KEY:-}" ]]; then
        printf "  %b•%b SSH: %s\n" "$GREEN" "$NC" "$PERSONAL_KEY"
    else
        printf "  %b•%b SSH: not generated. Run ssh-new or ssh-import.\n" "$YELLOW" "$NC"
    fi

    printf "  %b•%b Shell: %s\n" "$CYAN" "$NC" "${ZSH_PATH:-zsh}"
    printf "\n%bInstall complete.%b\n\n" "${BOLD}${GREEN}" "$NC"
}
