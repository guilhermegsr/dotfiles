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

printf "\n%b=== Dotfiles Secrets & SSH Backup ===%b\n" "${BOLD}${BLUE}" "$NC"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
DEFAULT_OUT_DIR="$HOME"

# Candidate paths relative to $HOME
CANDIDATES=(
    ".ssh/keys"
    ".ssh/config.local"
    ".ssh/conf.d"
    ".config/git/config.local"
    ".config/zsh/local.zsh"
)

section "Scanning for local secrets and untracked configurations..."

# Collect existing targets
TARGETS=()
for item in "${CANDIDATES[@]}"; do
    if [[ -e "$HOME/$item" ]]; then
        TARGETS+=("$item")
    fi
done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
    warn "No local secrets or SSH keys found to backup."
    exit 0
fi

info "Detected local assets to archive:"
for target in "${TARGETS[@]}"; do
    printf "    %b•%b %s\n" "$CYAN" "$NC" "$HOME/$target"
done

section "Configuring destination and encryption..."

# Output destination prompt
DEFAULT_ARCHIVE_NAME="dotfiles-backup-${TIMESTAMP}.tar.gz"
OUTPUT_FILE="${1:-}"

if [[ -z "$OUTPUT_FILE" ]]; then
    if [[ -t 0 ]]; then
        read -r -p "  Enter destination path [$DEFAULT_OUT_DIR/$DEFAULT_ARCHIVE_NAME]: " input_path
        OUTPUT_FILE="${input_path:-$DEFAULT_OUT_DIR/$DEFAULT_ARCHIVE_NAME}"
    else
        OUTPUT_FILE="$DEFAULT_OUT_DIR/$DEFAULT_ARCHIVE_NAME"
    fi
fi

# Expand tilde if present
OUTPUT_FILE="${OUTPUT_FILE/#\~/$HOME}"
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Encryption choice
ENCRYPT_CHOICE="n"
if [[ -t 0 ]]; then
    read -r -p "  Encrypt archive with password (AES-256-CBC via OpenSSL)? [y/N]: " ENCRYPT_CHOICE
fi

TEMP_TAR="$(mktemp)"
trap 'rm -f "$TEMP_TAR"' EXIT

# Package items relative to $HOME
tar -czf "$TEMP_TAR" -C "$HOME" "${TARGETS[@]}"

if [[ "$ENCRYPT_CHOICE" =~ ^[Yy]$ ]]; then
    if ! command -v openssl >/dev/null 2>&1; then
        error "'openssl' binary not found; unable to encrypt archive."
        exit 1
    fi

    # Append .enc if missing
    [[ "$OUTPUT_FILE" != *.enc ]] && OUTPUT_FILE="${OUTPUT_FILE}.enc"

    info "Encrypting archive..."
    if openssl enc -aes-256-cbc -pbkdf2 -salt -in "$TEMP_TAR" -out "$OUTPUT_FILE"; then
        chmod 600 "$OUTPUT_FILE"
        success "Encrypted backup saved to '$OUTPUT_FILE' (mode 0600)"
    else
        error "Encryption failed."
        exit 1
    fi
else
    mv "$TEMP_TAR" "$OUTPUT_FILE"
    chmod 600 "$OUTPUT_FILE"
    success "Backup saved to '$OUTPUT_FILE' (mode 0600)"
fi

printf "\n%bBackup completed successfully.%b\n\n" "${BOLD}${GREEN}" "$NC"
