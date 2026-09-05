#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$DOTFILES_DIR/scripts/lib.sh"

# Keep in sync with backup.sh CANDIDATES
ALLOWED_PREFIXES=(
    ".ssh/keys"
    ".ssh/config.local"
    ".ssh/conf.d"
    ".config/git/config.local"
    ".config/zsh/local.zsh"
)

OPENSSL_ITER=600000
OPENSSL_ITER_LEGACY=10000

usage() {
    cat <<'EOF'
Usage: restore.sh [--yes] [backup_archive]

  -y, --yes  Skip the confirmation prompt. The allowlist still applies.
  -h, --help Show this help

Only allowlisted paths are restored. Members with '..', absolute paths,
or symbolic links are rejected. Set DOTFILES_OPENSSL_PASS_FILE to a
passphrase file for non-interactive OpenSSL decryption.
EOF
}

path_is_allowed() {
    local p="$1"

    if [[ "$p" == *$'\n'* || "$p" == *$'\r'* ]]; then
        return 1
    fi

    while [[ "$p" == ./* ]]; do
        p="${p#./}"
    done
    p="${p%/}"

    if [[ -z "$p" || "$p" == /* || "$p" == ~* ]]; then
        return 1
    fi

    if [[ "$p" == [A-Za-z]:* ]]; then
        return 1
    fi

    local rest="$p"
    local part
    while [[ -n "$rest" ]]; do
        if [[ "$rest" == */* ]]; then
            part="${rest%%/*}"
            rest="${rest#*/}"
        else
            part="$rest"
            rest=""
        fi
        if [[ -z "$part" || "$part" == "." || "$part" == ".." ]]; then
            return 1
        fi
    done

    local prefix
    for prefix in "${ALLOWED_PREFIXES[@]}"; do
        if [[ "$p" == "$prefix" || "$p" == "$prefix"/* ]]; then
            return 0
        fi
    done
    return 1
}

is_tar_metadata_member() {
    local p="$1"
    [[ "$p" == pax_global_header ]] && return 0
    [[ "$p" == PaxHeaders.* || "$p" == */PaxHeaders.* ]] && return 0
    return 1
}

# Allowlisted paths plus their parent dirs (.ssh, .config, ...).
path_is_allowed_or_ancestor() {
    local p="$1"
    if path_is_allowed "$p"; then
        return 0
    fi
    local prefix
    for prefix in "${ALLOWED_PREFIXES[@]}"; do
        if [[ "$prefix" == "$p" || "$prefix" == "$p"/* ]]; then
            return 0
        fi
    done
    return 1
}

openssl_decrypt_with_iter() {
    local iter="$1"
    local src="$2"
    local dest="$3"
    local pass="$4"
    local tmp
    tmp="$(mktemp)"

    if openssl enc -d -aes-256-cbc -pbkdf2 -iter "$iter" -in "$src" -out "$tmp" \
        -pass fd:3 3<<<"$pass" 2>/dev/null \
        && tar -tzf "$tmp" >/dev/null 2>&1; then
        mv "$tmp" "$dest"
        return 0
    fi
    rm -f "$tmp"
    return 1
}

ASSUME_YES=false
BACKUP_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes)
            ASSUME_YES=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            if [[ -n "$BACKUP_FILE" ]]; then
                error "Unexpected extra argument: $1"
                usage
                exit 1
            fi
            BACKUP_FILE="$1"
            shift
            ;;
    esac
done

printf "\n%b=== Restore ===%b\n" "${BOLD}${BLUE}" "$NC"

if [[ -z "$BACKUP_FILE" ]]; then
    if [[ -t 0 ]]; then
        read -r -p "  Enter path to backup archive: " BACKUP_FILE
    else
        error "No backup archive specified."
        exit 1
    fi
fi

BACKUP_FILE="${BACKUP_FILE/#\~/$HOME}"

if [[ ! -f "$BACKUP_FILE" ]]; then
    error "Backup file not found: $BACKUP_FILE"
    exit 1
fi

TEMP_TAR="$(mktemp)"
STAGE_DIR="$(mktemp -d)"
trap 'rm -f "$TEMP_TAR"; rm -rf "$STAGE_DIR"' EXIT

section "Archive"

if [[ "$BACKUP_FILE" == *.age ]]; then
    if ! command -v age >/dev/null 2>&1; then
        error "age is required to decrypt $BACKUP_FILE."
        exit 1
    fi
    info "Decrypting with age"
    if ! age -d -o "$TEMP_TAR" "$BACKUP_FILE"; then
        error "Decryption failed. Check the passphrase and try again."
        exit 1
    fi
elif [[ "$BACKUP_FILE" == *.enc ]]; then
    if ! command -v openssl >/dev/null 2>&1; then
        error "openssl is required to decrypt $BACKUP_FILE."
        exit 1
    fi
    info "Decrypting with OpenSSL"
    OPENSSL_PASS=""
    if [[ -n "${DOTFILES_OPENSSL_PASS_FILE:-}" ]]; then
        if [[ ! -f "$DOTFILES_OPENSSL_PASS_FILE" ]]; then
            error "Passphrase file not found: $DOTFILES_OPENSSL_PASS_FILE"
            exit 1
        fi
        OPENSSL_PASS="$(<"$DOTFILES_OPENSSL_PASS_FILE")"
        OPENSSL_PASS="${OPENSSL_PASS%%$'\n'*}"
    elif [[ -t 0 ]]; then
        read -r -s -p "  Enter decryption passphrase: " OPENSSL_PASS
        printf "\n"
    else
        error "OpenSSL decryption requires a terminal or DOTFILES_OPENSSL_PASS_FILE."
        exit 1
    fi
    if openssl_decrypt_with_iter "$OPENSSL_ITER" "$BACKUP_FILE" "$TEMP_TAR" "$OPENSSL_PASS"; then
        info "Decrypted with PBKDF2, ${OPENSSL_ITER} iterations"
    elif openssl_decrypt_with_iter "$OPENSSL_ITER_LEGACY" "$BACKUP_FILE" "$TEMP_TAR" "$OPENSSL_PASS"; then
        warn "Decrypted with legacy PBKDF2, ${OPENSSL_ITER_LEGACY} iterations. Create a new backup to upgrade."
    else
        unset OPENSSL_PASS
        error "Decryption failed. Check the passphrase and try again."
        exit 1
    fi
    unset OPENSSL_PASS
else
    if ! tar -tzf "$BACKUP_FILE" >/dev/null 2>&1; then
        error "This is not a gzip tar archive. Encrypted backups use .enc or .age."
        exit 1
    fi
    cp "$BACKUP_FILE" "$TEMP_TAR"
fi

if ! tar -tzf "$TEMP_TAR" >/dev/null 2>&1; then
    error "The decrypted data is not a valid gzip tar archive."
    exit 1
fi

section "Members"

VALID_MEMBERS=()
while IFS= read -r member; do
    [[ -z "$member" ]] && continue
    if is_tar_metadata_member "$member"; then
        continue
    fi
    if ! path_is_allowed "$member"; then
        error "Refusing to restore disallowed path: $member"
        error "Allowed prefixes: ${ALLOWED_PREFIXES[*]}"
        exit 1
    fi
    VALID_MEMBERS+=("$member")
done < <(tar -tzf "$TEMP_TAR")

if [[ ${#VALID_MEMBERS[@]} -eq 0 ]]; then
    error "The archive has no allowed members."
    exit 1
fi

info "The following paths will be restored to $HOME:"
for member in "${VALID_MEMBERS[@]}"; do
    printf "    %b•%b %s\n" "$CYAN" "$NC" "$member"
done

if [[ "$ASSUME_YES" != true ]]; then
    if [[ ! -t 0 ]]; then
        error "Non-interactive restore requires --yes."
        exit 1
    fi
    read -r -p "  Restore these files into $HOME? [y/N]: " confirm_restore
    if [[ ! "${confirm_restore:-}" =~ ^[Yy]$ ]]; then
        warn "Restore cancelled."
        exit 0
    fi
fi

info "Extracting to a staging directory"
# Extract the whole archive; listing child members after a dir makes GNU tar error.
tar -xzf "$TEMP_TAR" -C "$STAGE_DIR"

while IFS= read -r -d '' staged; do
    [[ "$staged" == "$STAGE_DIR" ]] && continue
    local_rel="${staged#"$STAGE_DIR"/}"
    if ! path_is_allowed_or_ancestor "$local_rel"; then
        error "Unexpected path after extraction: $local_rel"
        exit 1
    fi
done < <(find "$STAGE_DIR" -print0)

symlink_found=false
while IFS= read -r -d '' _; do
    symlink_found=true
    break
done < <(find "$STAGE_DIR" -type l -print0 2>/dev/null)

if [[ "$symlink_found" == true ]]; then
    error "Refusing to restore: the archive contains symbolic links."
    exit 1
fi

info "Copying files into $HOME"
cp -a "$STAGE_DIR"/. "$HOME"/

section "Permissions"

if [[ -e "$HOME/.ssh/keys" || -e "$HOME/.ssh/config.local" || -e "$HOME/.ssh/conf.d" ]]; then
    chmod 700 "$HOME/.ssh"
fi

if [[ -d "$HOME/.ssh/keys" ]]; then
    find "$HOME/.ssh/keys" -type d -exec chmod 700 {} +
    find "$HOME/.ssh/keys" -type f ! -name "*.pub" -exec chmod 600 {} +
    find "$HOME/.ssh/keys" -type f -name "*.pub" -exec chmod 644 {} +
    info "Updated permissions on ~/.ssh/keys"
fi

if [[ -f "$HOME/.ssh/config.local" ]]; then
    chmod 600 "$HOME/.ssh/config.local"
fi

if [[ -d "$HOME/.ssh/conf.d" ]]; then
    find "$HOME/.ssh/conf.d" -type d -exec chmod 700 {} +
    find "$HOME/.ssh/conf.d" -type f -exec chmod 600 {} +
    info "Updated permissions on ~/.ssh/conf.d"
fi

if [[ -f "$HOME/.config/git/config.local" ]]; then
    chmod 600 "$HOME/.config/git/config.local"
fi

if [[ -f "$HOME/.config/zsh/local.zsh" ]]; then
    chmod 600 "$HOME/.config/zsh/local.zsh"
fi

success "Allowed paths restored"
printf "\n%bRestore complete.%b\n\n" "${BOLD}${GREEN}" "$NC"
