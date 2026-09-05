#!/usr/bin/env bash

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

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

section() {
    printf "\n%b==>%b %b%s%b\n" "$CYAN" "$NC" "$BOLD" "$1" "$NC"
}

info() {
    printf "  %b[INFO]%b %s\n" "$BLUE" "$NC" "$1"
}

success() {
    printf "  %b[OK]%b   %s\n" "$GREEN" "$NC" "$1"
}

warn() {
    printf "  %b[WARN]%b %s\n" "$YELLOW" "$NC" "$1"
}

error() {
    printf "  %b[ERROR]%b %s\n" "$RED" "$NC" "$1" >&2
}

usage() {
    cat <<'EOF'
Usage: restore.sh [--yes] [backup_archive]

  -y, --yes  Skip the interactive confirmation (still enforces the allowlist)
  -h, --help Show this help

Only members under the backup allowlist are restored. Archives containing
'..', absolute paths, symlinks, or unexpected prefixes are rejected.
EOF
}

# Returns 0 if the tar member is a safe allowlisted path.
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

# Allowlisted paths plus parent directories required to hold them (.ssh, .config, ...).
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
            error "Unknown option '$1'"
            usage
            exit 1
            ;;
        *)
            if [[ -n "$BACKUP_FILE" ]]; then
                error "Unexpected extra argument '$1'"
                usage
                exit 1
            fi
            BACKUP_FILE="$1"
            shift
            ;;
    esac
done

printf "\n%b=== Dotfiles Secrets & SSH Restoration ===%b\n" "${BOLD}${BLUE}" "$NC"

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
    error "Backup file '$BACKUP_FILE' does not exist."
    exit 1
fi

TEMP_TAR="$(mktemp)"
STAGE_DIR="$(mktemp -d)"
trap 'rm -f "$TEMP_TAR"; rm -rf "$STAGE_DIR"' EXIT

section "Opening archive..."

if [[ "$BACKUP_FILE" == *.age ]]; then
    if ! command -v age >/dev/null 2>&1; then
        error "'age' is required to decrypt '$BACKUP_FILE'."
        exit 1
    fi
    info "Decrypting age archive..."
    if ! age -d -o "$TEMP_TAR" "$BACKUP_FILE"; then
        error "Decryption failed (incorrect password or corrupted archive)."
        exit 1
    fi
elif [[ "$BACKUP_FILE" == *.enc ]]; then
    if ! command -v openssl >/dev/null 2>&1; then
        error "'openssl' is required to decrypt '$BACKUP_FILE'."
        exit 1
    fi
    info "Decrypting OpenSSL archive..."
    if [[ ! -t 0 ]]; then
        error "OpenSSL password decryption requires a TTY."
        exit 1
    fi
    read -r -s -p "  Enter decryption passphrase: " OPENSSL_PASS
    printf "\n"
    if openssl_decrypt_with_iter "$OPENSSL_ITER" "$BACKUP_FILE" "$TEMP_TAR" "$OPENSSL_PASS"; then
        info "Decrypted with PBKDF2 iter=${OPENSSL_ITER}"
    elif openssl_decrypt_with_iter "$OPENSSL_ITER_LEGACY" "$BACKUP_FILE" "$TEMP_TAR" "$OPENSSL_PASS"; then
        warn "Decrypted with legacy PBKDF2 iter=${OPENSSL_ITER_LEGACY}; re-backup to upgrade"
    else
        unset OPENSSL_PASS
        error "Decryption failed (incorrect password or corrupted archive)."
        exit 1
    fi
    unset OPENSSL_PASS
else
    if ! tar -tzf "$BACKUP_FILE" >/dev/null 2>&1; then
        error "Not a gzip compressed tar archive. Encrypted backups use .enc (OpenSSL) or .age."
        exit 1
    fi
    cp "$BACKUP_FILE" "$TEMP_TAR"
fi

if ! tar -tzf "$TEMP_TAR" >/dev/null 2>&1; then
    error "Archive is not a valid gzip compressed tar after decryption."
    exit 1
fi

section "Validating archive members..."

VALID_MEMBERS=()
while IFS= read -r member; do
    [[ -z "$member" ]] && continue
    if is_tar_metadata_member "$member"; then
        continue
    fi
    if ! path_is_allowed "$member"; then
        error "Refusing restore: disallowed archive member '$member'"
        error "Allowed prefixes: ${ALLOWED_PREFIXES[*]}"
        exit 1
    fi
    VALID_MEMBERS+=("$member")
done < <(tar -tzf "$TEMP_TAR")

if [[ ${#VALID_MEMBERS[@]} -eq 0 ]]; then
    error "Archive contains no allowlisted members."
    exit 1
fi

info "Archive members to restore into '$HOME':"
for member in "${VALID_MEMBERS[@]}"; do
    printf "    %b•%b %s\n" "$CYAN" "$NC" "$member"
done

if [[ "$ASSUME_YES" != true ]]; then
    if [[ ! -t 0 ]]; then
        error "Refusing non-interactive restore without --yes."
        exit 1
    fi
    read -r -p "  Restore these files into $HOME? [y/N]: " confirm_restore
    if [[ ! "${confirm_restore:-}" =~ ^[Yy]$ ]]; then
        warn "Restore aborted."
        exit 0
    fi
fi

info "Extracting archive into a staging directory..."
# All members were allowlisted above; extract the full archive into the
# staging dir (passing child names after a parent directory member makes
# GNU tar report "Not found in archive").
tar -xzf "$TEMP_TAR" -C "$STAGE_DIR"

while IFS= read -r -d '' staged; do
    [[ "$staged" == "$STAGE_DIR" ]] && continue
    local_rel="${staged#"$STAGE_DIR"/}"
    if ! path_is_allowed_or_ancestor "$local_rel"; then
        error "Refusing restore: unexpected path after extract '$local_rel'"
        exit 1
    fi
done < <(find "$STAGE_DIR" -print0)

symlink_found=false
while IFS= read -r -d '' _; do
    symlink_found=true
    break
done < <(find "$STAGE_DIR" -type l -print0 2>/dev/null)

if [[ "$symlink_found" == true ]]; then
    error "Refusing restore: archive contains symbolic links."
    exit 1
fi

info "Copying restored files into '$HOME'..."
cp -a "$STAGE_DIR"/. "$HOME"/

section "Enforcing strict POSIX permissions on restored assets..."

if [[ -e "$HOME/.ssh/keys" || -e "$HOME/.ssh/config.local" || -e "$HOME/.ssh/conf.d" ]]; then
    chmod 700 "$HOME/.ssh"
fi

if [[ -d "$HOME/.ssh/keys" ]]; then
    find "$HOME/.ssh/keys" -type d -exec chmod 700 {} +
    find "$HOME/.ssh/keys" -type f ! -name "*.pub" -exec chmod 600 {} +
    find "$HOME/.ssh/keys" -type f -name "*.pub" -exec chmod 644 {} +
    info "Permissions updated for ~/.ssh/keys"
fi

if [[ -f "$HOME/.ssh/config.local" ]]; then
    chmod 600 "$HOME/.ssh/config.local"
fi

if [[ -d "$HOME/.ssh/conf.d" ]]; then
    find "$HOME/.ssh/conf.d" -type d -exec chmod 700 {} +
    find "$HOME/.ssh/conf.d" -type f -exec chmod 600 {} +
    info "Permissions updated for ~/.ssh/conf.d"
fi

if [[ -f "$HOME/.config/git/config.local" ]]; then
    chmod 600 "$HOME/.config/git/config.local"
fi

if [[ -f "$HOME/.config/zsh/local.zsh" ]]; then
    chmod 600 "$HOME/.config/zsh/local.zsh"
fi

success "Allowlisted archive assets restored successfully."
printf "\n%bRestoration completed successfully.%b\n\n" "${BOLD}${GREEN}" "$NC"
