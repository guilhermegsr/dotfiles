#!/usr/bin/env bash

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

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

printf "\n%b=== Dotfiles Secrets & SSH Restoration ===%b\n" "${BOLD}${BLUE}" "$NC"

BACKUP_FILE="${1:-}"

if [[ -z "$BACKUP_FILE" ]]; then
    if [[ -t 0 ]]; then
        read -r -p "  Enter path to backup archive: " BACKUP_FILE
    else
        error "No backup archive specified."
        exit 1
    fi
fi

# Expand tilde if present
BACKUP_FILE="${BACKUP_FILE/#\~/$HOME}"

if [[ ! -f "$BACKUP_FILE" ]]; then
    error "Backup file '$BACKUP_FILE' does not exist."
    exit 1
fi

TEMP_TAR="$(mktemp)"
trap 'rm -f "$TEMP_TAR"' EXIT

# Detect if the archive is encrypted (either .enc extension or tar test failure)
IS_ENCRYPTED=false
if [[ "$BACKUP_FILE" == *.enc ]] || ! tar -tzf "$BACKUP_FILE" >/dev/null 2>&1; then
    IS_ENCRYPTED=true
fi

if [[ "$IS_ENCRYPTED" == "true" ]]; then
    if ! command -v openssl >/dev/null 2>&1; then
        error "'openssl' required to decrypt '$BACKUP_FILE'."
        exit 1
    fi

    info "Encrypted backup detected. Please enter decryption passphrase:"
    if ! openssl enc -d -aes-256-cbc -pbkdf2 -in "$BACKUP_FILE" -out "$TEMP_TAR"; then
        error "Decryption failed (incorrect password or corrupted archive)."
        exit 1
    fi
else
    cp "$BACKUP_FILE" "$TEMP_TAR"
fi

info "Restoring archive contents to '$HOME'..."
tar -xzf "$TEMP_TAR" -C "$HOME"

# Apply strict POSIX permissions across restored assets
section "Enforcing strict POSIX permissions on restored assets..."

if [[ -d "$HOME/.ssh" ]]; then
    chmod 700 "$HOME/.ssh" 2>/dev/null || true
    find "$HOME/.ssh" -type d -exec chmod 700 {} + 2>/dev/null || true
    find "$HOME/.ssh" -type f ! -name "*.pub" -exec chmod 600 {} + 2>/dev/null || true
    find "$HOME/.ssh" -type f -name "*.pub" -exec chmod 644 {} + 2>/dev/null || true
    info "Permissions updated for ~/.ssh (directories: 700, keys/configs: 600, pubkeys: 644)"
fi

if [[ -f "$HOME/.config/git/config.local" ]]; then
    chmod 600 "$HOME/.config/git/config.local" 2>/dev/null || true
fi

if [[ -f "$HOME/.config/zsh/local.zsh" ]]; then
    chmod 600 "$HOME/.config/zsh/local.zsh" 2>/dev/null || true
fi

success "All archive assets restored successfully."
printf "\n%bRestoration completed successfully.%b\n\n" "${BOLD}${GREEN}" "$NC"
