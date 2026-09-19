# shellcheck shell=bash
mise_target_is_managed() {
    local target="$1"
    local marker="$STATE_DIR/managed-mise"
    [[ -f "$marker" && ! -L "$marker" && -f "$target" && ! -L "$target" ]] || return 1

    local recorded_path="" recorded_sha="" line key value
    while IFS= read -r line || [[ -n "$line" ]]; do
        key="${line%%=*}"
        value="${line#*=}"
        case "$key" in
            path) recorded_path="$value" ;;
            sha256) recorded_sha="$value" ;;
        esac
    done <"$marker"

    [[ "$recorded_path" == "$target" && "$recorded_sha" == "$(sha256_file "$target" 2>/dev/null || true)" ]]
}

record_managed_mise() {
    local path="$1"
    local version="$2"
    local checksum
    checksum="$(sha256_file "$path")"

    mkdir -p "$STATE_DIR"
    local marker_temp
    marker_temp="$(mktemp "$STATE_DIR/managed-mise.XXXXXX")"
    printf 'path=%s\nversion=%s\nsha256=%s\n' "$path" "$version" "$checksum" >"$marker_temp"
    chmod 600 "$marker_temp"
    mv "$marker_temp" "$STATE_DIR/managed-mise"
}

install_mise() {
    section "Mise"
    if [[ "$OFFLINE" == true ]]; then
        info "Skipping Mise and tool installation in offline mode"
        return 0
    fi

    export PATH="$HOME/.local/bin:$PATH"
    local mise_bin expected_version current_version=""
    mise_bin="$(command -v mise 2>/dev/null || true)"
    expected_version="${LOCK_MISE_VERSION#v}"

    local install_pinned_mise=true
    if [[ -n "$mise_bin" && -x "$mise_bin" ]]; then
        current_version="$("$mise_bin" --version 2>/dev/null | awk '{print $1}')"
        if [[ "$current_version" == "$expected_version" ]]; then
            info "Mise ${expected_version} is already installed at $mise_bin"
            install_pinned_mise=false
        else
            info "Found Mise ${current_version:-unknown} at $mise_bin; installing ${LOCK_MISE_VERSION}"
        fi
    fi

    if [[ "$install_pinned_mise" == true ]]; then
        if command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
            local mise_triple mise_sha
            if mise_triple="$(os_triple)"; then
                mise_sha="$(mise_sha256_for_triple "$mise_triple")"
                if [[ -z "$mise_sha" ]]; then
                    warn "No pinned checksum for Mise on $mise_triple"
                else
                    info "Downloading Mise ${LOCK_MISE_VERSION} $mise_triple"
                    mkdir -p "$HOME/.local/bin"
                    local mise_temp mise_archive mise_url
                    mise_temp="$(mktemp -d)"
                    mise_archive="$(mktemp)"
                    mise_url="https://github.com/jdx/mise/releases/download/${LOCK_MISE_VERSION}/mise-${LOCK_MISE_VERSION}-${mise_triple}.tar.gz"
                    if curl -fsSL "$mise_url" -o "$mise_archive" \
                        && verify_sha256 "$mise_archive" "$mise_sha" \
                        && tar -xzf "$mise_archive" -C "$mise_temp"; then
                        local mise_target="$HOME/.local/bin/mise"
                        if [[ -e "$mise_target" || -L "$mise_target" ]] && ! mise_target_is_managed "$mise_target"; then
                            warn "Preserving unowned Mise binary before replacement"
                            backup_if_exists "$mise_target"
                        fi
                        cp "$mise_temp/mise/bin/mise" "$mise_target"
                        chmod 755 "$mise_target"
                        rm -rf "$mise_temp" "$mise_archive"
                        mise_bin="$mise_target"
                        record_managed_mise "$mise_bin" "$expected_version"
                        success "Installed Mise ${LOCK_MISE_VERSION} to $mise_bin"
                    else
                        warn "Could not download or verify Mise; skipping"
                        rm -rf "$mise_temp" "$mise_archive"
                        mise_bin="$(command -v mise 2>/dev/null || true)"
                    fi
                fi
            else
                warn "This platform is not supported for the pinned Mise install"
            fi
        else
            warn "curl and tar are required to install Mise. See https://mise.jdx.dev"
        fi
    fi

    if [[ -n "$mise_bin" && -x "$mise_bin" ]]; then
        info "Installing tools declared in Mise"
        if "$mise_bin" install; then
            success "Mise tools installed"
        else
            warn "Mise tool installation failed. Run 'mise install' to inspect."
        fi
    fi
}
