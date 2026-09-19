# shellcheck shell=bash
install_fonts() {
    section "Fonts"
    local font_dir legacy_font_dir font_manifest font_tag_marker installed_tag=""
    font_dir="$(dotfiles_font_dir "$DATA_DIR")"
    legacy_font_dir="$(dotfiles_legacy_font_dir "$DATA_DIR")"
    font_manifest="$STATE_DIR/installed-fonts"
    font_tag_marker="$STATE_DIR/installed-font-tag"

    if [[ "$OFFLINE" == true ]]; then
        info "Skipping Nerd Font download in offline mode"
        return 0
    fi

    # Presence alone never upgrades: without the tag, a bump in the lock
    # would never reach a machine that already has the font.
    [[ -f "$font_tag_marker" ]] && installed_tag="$(<"$font_tag_marker")"
    if [[ "$installed_tag" == "$LOCK_FONT_TAG" ]] \
        && find "$font_dir" -maxdepth 1 -iname "*JetBrainsMono*Nerd*" 2>/dev/null | grep -q .; then
        info "JetBrainsMono Nerd Font ${LOCK_FONT_TAG} is already installed"
        return 0
    fi
    if ! command -v curl >/dev/null 2>&1 || ! command -v tar >/dev/null 2>&1; then
        warn "curl and tar are required to install fonts"
        return 0
    fi

    info "Downloading JetBrainsMono Nerd Font ${LOCK_FONT_TAG}"
    local font_temp font_archive font_url
    font_temp="$(mktemp -d)"
    font_archive="$(mktemp)"
    font_url="https://github.com/ryanoasis/nerd-fonts/releases/download/${LOCK_FONT_TAG}/${LOCK_FONT_ASSET}"

    if curl -fsSL "$font_url" -o "$font_archive" \
        && verify_sha256 "$font_archive" "$LOCK_FONT_SHA256" \
        && tar -xJ -f "$font_archive" -C "$font_temp"; then
        mkdir -p "$STATE_DIR"
        local manifest_temp installed_font_count font_source font_name
        manifest_temp="$(mktemp "$STATE_DIR/installed-fonts.XXXXXX")"
        installed_font_count=0
        while IFS= read -r -d '' font_source; do
            font_name="$(basename "$font_source")"
            printf '%s\n' "$font_name" >>"$manifest_temp"
            installed_font_count=$((installed_font_count + 1))
        done < <(find "$font_temp" -maxdepth 1 -type f \( -name "*.ttf" -o -name "*.otf" \) -print0)

        if [[ $installed_font_count -eq 0 ]]; then
            warn "The font archive contained no TTF or OTF files; skipping"
            rm -f "$manifest_temp"
        else
            # Nothing is removed until the download verifies. Installs older
            # than the dedicated directory left the files loose beside it.
            remove_manifest_fonts "$font_dir" "$font_manifest"
            remove_manifest_fonts "$legacy_font_dir" "$font_manifest"
            chmod 600 "$manifest_temp"
            mv "$manifest_temp" "$font_manifest"
            mkdir -p "$font_dir"
            while IFS= read -r font_name; do
                cp "$font_temp/$font_name" "$font_dir/$font_name"
            done <"$font_manifest"
            printf '%s\n' "$LOCK_FONT_TAG" >"$font_tag_marker"
            chmod 600 "$font_tag_marker"
        fi
        rm -rf "$font_temp" "$font_archive"

        if [[ $installed_font_count -gt 0 ]] && command -v fc-cache >/dev/null 2>&1; then
            fc-cache -f "$legacy_font_dir" >/dev/null 2>&1 || true
        fi
        if [[ $installed_font_count -gt 0 ]]; then
            success "Installed JetBrainsMono Nerd Font ${LOCK_FONT_TAG} to $font_dir"
        fi
    else
        warn "Could not download or verify the font; skipping"
        rm -rf "$font_temp" "$font_archive"
    fi
}
