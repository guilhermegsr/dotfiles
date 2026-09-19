# shellcheck shell=bash
configure_login_shell() {
    section "Login shell"
    ZSH_PATH="$(command -v zsh 2>/dev/null || true)"

    if [[ -z "$ZSH_PATH" ]]; then
        warn "zsh was not found in PATH"
        return 0
    fi

    local current_user current_shell=""
    current_user="${USER:-${LOGNAME:-}}"
    if [[ -z "$current_user" ]]; then
        current_user="$(whoami 2>/dev/null || true)"
    fi
    if command -v getent >/dev/null 2>&1 && [[ -n "$current_user" ]]; then
        current_shell="$(getent passwd "$current_user" 2>/dev/null | cut -d: -f7 || true)"
    fi
    [[ -z "$current_shell" ]] && current_shell="${SHELL:-}"

    if [[ "$current_shell" == "$ZSH_PATH" ]]; then
        info "Login shell is already $ZSH_PATH"
        return 0
    fi

    info "Setting login shell to $ZSH_PATH"

    # Nothing is recorded on the paths that leave the shell alone: uninstall
    # reads this file to run chsh, and must only revert a switch we made.
    if [[ "$SKIP_CHSH" == true ]]; then
        info "Skipping chsh; would switch to $ZSH_PATH"
        return 0
    fi
    if ! command -v chsh >/dev/null 2>&1; then
        warn "chsh was not found; set the login shell manually"
        return 0
    fi

    # Written before the switch so an interrupted chsh still leaves a trail,
    # and dropped again when chsh refuses, which leaves the shell unchanged.
    local previous_shell_file recorded_now=false
    previous_shell_file="$(dotfiles_previous_shell_file)"
    mkdir -p "$(dirname "$previous_shell_file")"
    if [[ ! -f "$previous_shell_file" && -n "$current_shell" ]]; then
        printf '%s\n' "$current_shell" >"$previous_shell_file"
        chmod 600 "$previous_shell_file"
        recorded_now=true
    fi

    if chsh -s "$ZSH_PATH"; then
        success "Login shell set to $ZSH_PATH"
    else
        [[ "$recorded_now" == true ]] && rm -f "$previous_shell_file"
        warn "Could not change the login shell. Run: chsh -s $ZSH_PATH"
    fi
}

report_terminal() {
    section "Terminal"
    if command -v alacritty >/dev/null 2>&1; then
        local alacritty_version
        alacritty_version="$(alacritty --version 2>/dev/null | head -n 1 || echo 'detected')"
        success "Alacritty $alacritty_version"
    else
        info "Alacritty is not installed; config deployed to $CONFIG_DIR/alacritty"
    fi
}
