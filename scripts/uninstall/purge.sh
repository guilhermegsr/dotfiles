# shellcheck shell=bash
purge_managed_plugins() {
    local manifest="$STATE_DIR/installed-plugins"
    local plugin_root="$DATA_DIR/zsh/plugins"
    if [[ -L "$manifest" ]]; then
        warn "Refusing symlinked plugin manifest: $manifest"
        return 0
    fi
    if [[ ! -f "$manifest" ]]; then
        info "No managed plugin manifest; leaving plugins untouched"
        return 0
    fi

    local retained
    retained="$(mktemp "$STATE_DIR/installed-plugins.retained.XXXXXX")"
    local name url plugin_path origin_url dirty
    while IFS=$'\t' read -r name url || [[ -n "${name:-}" ]]; do
        [[ -z "${name:-}" ]] && continue
        if [[ ! "$name" =~ ^[a-zA-Z0-9._-]+$ || "$url" != https://* ]]; then
            warn "Preserving invalid plugin manifest entry: $name"
            printf '%s\t%s\n' "$name" "$url" >>"$retained"
            continue
        fi

        plugin_path="$plugin_root/$name"
        if [[ ! -e "$plugin_path" && ! -L "$plugin_path" ]]; then
            info "Managed plugin is already absent: $name"
            continue
        fi
        if [[ -L "$plugin_path" || ! -d "$plugin_path/.git" ]]; then
            warn "Preserving $plugin_path because it is not a regular Git checkout"
            printf '%s\t%s\n' "$name" "$url" >>"$retained"
            continue
        fi

        origin_url="$(git -C "$plugin_path" remote get-url origin 2>/dev/null || true)"
        dirty="$(git -C "$plugin_path" status --porcelain 2>/dev/null || printf 'unknown')"
        if [[ "$origin_url" != "$url" ]]; then
            warn "Preserving $name because its origin changed to ${origin_url:-none}"
            printf '%s\t%s\n' "$name" "$url" >>"$retained"
        elif [[ -n "$dirty" ]]; then
            warn "Preserving $name because its checkout has local changes"
            printf '%s\t%s\n' "$name" "$url" >>"$retained"
        else
            rm -rf -- "$plugin_path"
            success "Removed managed plugin $name"
        fi
    done <"$manifest"

    if [[ -s "$retained" ]]; then
        chmod 600 "$retained"
        mv "$retained" "$manifest"
    else
        rm -f "$retained" "$manifest"
    fi
}

purge_managed_mise() {
    local marker="$STATE_DIR/managed-mise"
    if [[ -L "$marker" ]]; then
        warn "Refusing symlinked Mise marker: $marker"
        return 0
    fi
    if [[ ! -f "$marker" ]]; then
        info "No managed Mise marker; leaving Mise untouched"
        return 0
    fi

    local managed_path="" managed_version="" managed_sha="" line key value
    while IFS= read -r line || [[ -n "$line" ]]; do
        key="${line%%=*}"
        value="${line#*=}"
        case "$key" in
            path) managed_path="$value" ;;
            version) managed_version="$value" ;;
            sha256) managed_sha="$value" ;;
        esac
    done <"$marker"

    local expected_path="$HOME/.local/bin/mise"
    if [[ "$managed_path" != "$expected_path" || -z "$managed_version" || ! "$managed_sha" =~ ^[0-9a-f]{64}$ ]]; then
        warn "Preserving Mise because its ownership marker is invalid"
        return 0
    fi
    if [[ ! -e "$managed_path" && ! -L "$managed_path" ]]; then
        rm -f "$marker"
        info "Managed Mise binary is already absent"
        return 0
    fi
    if [[ -L "$managed_path" || ! -f "$managed_path" ]]; then
        warn "Preserving Mise because $managed_path is not a regular file"
        return 0
    fi

    local current_version current_sha
    current_version="$("$managed_path" --version 2>/dev/null | awk '{print $1}' || true)"
    current_sha="$(sha256_file "$managed_path" 2>/dev/null || true)"
    if [[ "$current_version" != "$managed_version" || "$current_sha" != "$managed_sha" ]]; then
        warn "Preserving Mise because the managed binary was modified"
        return 0
    fi

    rm -f "$managed_path" "$marker"
    PURGED_MISE_BINARY=true
    success "Removed dotfiles-managed Mise $managed_version"
}

# `mise install` provisions gigabytes of tools beside the binary. They are only
# reachable through a Mise, so removing the one we own orphans them -- unless
# the machine still has another, which then owns them and keeps them.
purge_managed_mise_data() {
    local remaining
    remaining="$(command -v mise 2>/dev/null || true)"
    if [[ -n "$remaining" ]]; then
        warn "Keeping the Mise data; another Mise is still installed at $remaining"
        return 0
    fi

    local dir size removed=0
    for dir in "$DATA_DIR/mise" \
        "${XDG_STATE_HOME:-$HOME/.local/state}/mise" \
        "${XDG_CACHE_HOME:-$HOME/.cache}/mise"; do
        [[ -d "$dir" && ! -L "$dir" ]] || continue
        size="$(du -sh "$dir" 2>/dev/null | cut -f1 || true)"
        rm -rf -- "$dir"
        info "Removed $dir${size:+ ($size)}"
        removed=$((removed + 1))
    done

    if [[ $removed -gt 0 ]]; then
        success "Removed the tools the managed Mise had installed"
    else
        info "The managed Mise had installed no tools"
    fi
}

purge_managed_assets() {
    section "Purge managed assets"
    PURGED_MISE_BINARY=false
    purge_managed_plugins
    purge_managed_mise
    if [[ "$PURGED_MISE_BINARY" == true ]]; then
        purge_managed_mise_data
    fi
    sweep_stale_staging "$DATA_DIR/zsh/plugins" ".dotfiles-plugin.*"
    rmdir "$DATA_DIR/zsh/plugins" "$DATA_DIR/zsh" "$DATA_DIR/fonts" \
        "$HOME/.local/bin" "$STATE_DIR" 2>/dev/null || true
}
