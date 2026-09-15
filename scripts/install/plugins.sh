record_managed_plugin() {
    local name="$1"
    local url="$2"

    mkdir -p "$STATE_DIR"
    if [[ -L "$PLUGIN_MANIFEST" || ( -e "$PLUGIN_MANIFEST" && ! -f "$PLUGIN_MANIFEST" ) ]]; then
        error "Refusing unsafe plugin manifest: $PLUGIN_MANIFEST"
        return 1
    fi
    touch "$PLUGIN_MANIFEST"
    chmod 600 "$PLUGIN_MANIFEST"
    if ! awk -F '\t' -v plugin="$name" '$1 == plugin { found=1 } END { exit !found }' "$PLUGIN_MANIFEST"; then
        printf '%s\t%s\n' "$name" "$url" >>"$PLUGIN_MANIFEST"
    fi
}

install_plugin_at_sha() {
    local name="$1"
    local url="$2"
    local sha="$3"
    local dir="$PLUGIN_DIR/$name"
    local created_checkout=false

    if [[ ! "$name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        error "Invalid plugin name: $name"
        return 1
    fi
    if [[ ! "$sha" =~ ^[0-9a-f]{40}$ ]]; then
        error "Invalid plugin SHA for $name: $sha"
        return 1
    fi

    if [[ -d "$dir/.git" ]]; then
        local origin_url
        origin_url="$(git -C "$dir" remote get-url origin 2>/dev/null || true)"
        if [[ "$origin_url" != "$url" ]]; then
            warn "$name has an unexpected origin: ${origin_url:-none}"
            backup_if_exists "$dir"
        fi
    elif [[ -e "$dir" || -L "$dir" ]]; then
        warn "$dir exists but is not a managed Git checkout"
        backup_if_exists "$dir"
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
        local clone_dir
        clone_dir="$(mktemp -d "$PLUGIN_DIR/.${name}.XXXXXX")"
        info "Cloning $name at ${sha:0:12}"
        if git -C "$clone_dir" init --quiet \
            && git -C "$clone_dir" remote add origin "$url" \
            && git -C "$clone_dir" fetch --depth 1 origin "$sha" \
            && git -C "$clone_dir" checkout --detach FETCH_HEAD --quiet; then
            mv "$clone_dir" "$dir"
            created_checkout=true
        else
            rm -rf "$clone_dir"
            error "Could not clone $name"
            return 1
        fi
    fi

    local resolved
    resolved="$(git -C "$dir" rev-parse HEAD)"
    if [[ "$resolved" != "$sha" ]]; then
        error "Plugin $name is at $resolved, expected $sha"
        return 1
    fi
    if [[ "$created_checkout" == true ]]; then
        record_managed_plugin "$name" "$url"
    fi
    success "Installed $name at ${sha:0:12}"
}

install_plugins() {
    section "Plugins"
    PLUGIN_DIR="$DATA_DIR/zsh/plugins"
    PLUGIN_MANIFEST="$STATE_DIR/installed-plugins"
    mkdir -p "$PLUGIN_DIR"

    if [[ "$OFFLINE" == true ]]; then
        info "Skipping Zsh plugin downloads in offline mode"
    elif command -v git >/dev/null 2>&1; then
        while read -r plugin_name plugin_url plugin_sha _plugin_branch; do
            [[ -z "${plugin_name:-}" || "$plugin_name" == \#* ]] && continue
            install_plugin_at_sha "$plugin_name" "$plugin_url" "$plugin_sha"
        done <"$DOTFILES_DIR/locks/zsh-plugins.lock"
    else
        warn "git was not found; skipping Zsh plugins"
    fi
}
