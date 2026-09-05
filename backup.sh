#!/usr/bin/env bash

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Keep in sync with restore.sh ALLOWED_PREFIXES
CANDIDATES=(
    ".ssh/keys"
    ".ssh/config.local"
    ".ssh/conf.d"
    ".config/git/config.local"
    ".config/zsh/local.zsh"
)

# OpenSSL enc does not store the iteration count; restore.sh tries this
# value first, then the historical default (10000) for older archives.
OPENSSL_ITER=600000

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
Usage: backup.sh [--plain] [output_path]

  --plain    Write an unencrypted tar.gz (NOT recommended; contains SSH keys)
  -h, --help Show this help

Encryption is on by default. Prefers age (authenticated); falls back to
OpenSSL AES-256-CBC with PBKDF2 (600000 iterations).
EOF
}

PLAIN=false
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --plain)
            PLAIN=true
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
            if [[ -n "$OUTPUT_FILE" ]]; then
                error "Unexpected extra argument '$1'"
                usage
                exit 1
            fi
            OUTPUT_FILE="$1"
            shift
            ;;
    esac
done

printf "\n%b=== Dotfiles Secrets & SSH Backup ===%b\n" "${BOLD}${BLUE}" "$NC"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
DEFAULT_OUT_DIR="$HOME"

section "Scanning for local secrets and untracked configurations..."

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

ENCRYPT=true
if [[ "$PLAIN" == true ]]; then
    ENCRYPT=false
elif [[ -t 0 ]]; then
    read -r -p "  Encrypt archive with a password? [Y/n]: " encrypt_choice
    if [[ "${encrypt_choice:-}" =~ ^[Nn] ]]; then
        ENCRYPT=false
    fi
else
    error "Encryption is on by default and requires a TTY for the passphrase."
    error "Re-run interactively, or pass --plain to write an unencrypted archive."
    exit 1
fi

ENCRYPT_TOOL=""
DEFAULT_ARCHIVE_NAME="dotfiles-backup-${TIMESTAMP}.tar.gz"

if [[ "$ENCRYPT" == true ]]; then
    if command -v age >/dev/null 2>&1; then
        ENCRYPT_TOOL="age"
        DEFAULT_ARCHIVE_NAME="${DEFAULT_ARCHIVE_NAME}.age"
        info "Using age (authenticated encryption)"
    elif command -v openssl >/dev/null 2>&1; then
        ENCRYPT_TOOL="openssl"
        DEFAULT_ARCHIVE_NAME="${DEFAULT_ARCHIVE_NAME}.enc"
        info "Using OpenSSL AES-256-CBC (PBKDF2, ${OPENSSL_ITER} iterations)"
        warn "age is preferred (AEAD). Install age to get authenticated encryption."
    else
        error "Encryption requires 'age' or 'openssl'. Install one of them, or pass --plain."
        exit 1
    fi
else
    warn "Writing an UNENCRYPTED archive that contains SSH private keys."
fi

if [[ -z "$OUTPUT_FILE" ]]; then
    if [[ -t 0 ]]; then
        read -r -p "  Enter destination path [$DEFAULT_OUT_DIR/$DEFAULT_ARCHIVE_NAME]: " input_path
        OUTPUT_FILE="${input_path:-$DEFAULT_OUT_DIR/$DEFAULT_ARCHIVE_NAME}"
    else
        OUTPUT_FILE="$DEFAULT_OUT_DIR/$DEFAULT_ARCHIVE_NAME"
    fi
fi

OUTPUT_FILE="${OUTPUT_FILE/#\~/$HOME}"

if [[ "$ENCRYPT" == true && "$ENCRYPT_TOOL" == "age" && "$OUTPUT_FILE" != *.age ]]; then
    OUTPUT_FILE="${OUTPUT_FILE}.age"
fi
if [[ "$ENCRYPT" == true && "$ENCRYPT_TOOL" == "openssl" && "$OUTPUT_FILE" != *.enc ]]; then
    OUTPUT_FILE="${OUTPUT_FILE}.enc"
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

TEMP_TAR="$(mktemp)"
trap 'rm -f "$TEMP_TAR"' EXIT

tar -czf "$TEMP_TAR" -C "$HOME" "${TARGETS[@]}"

if [[ "$ENCRYPT" == true ]]; then
    info "Encrypting archive..."
    case "$ENCRYPT_TOOL" in
        age)
            if ! age -p -o "$OUTPUT_FILE" "$TEMP_TAR"; then
                error "Encryption failed."
                rm -f "$OUTPUT_FILE"
                exit 1
            fi
            ;;
        openssl)
            if ! openssl enc -aes-256-cbc -pbkdf2 -iter "$OPENSSL_ITER" -salt -in "$TEMP_TAR" -out "$OUTPUT_FILE"; then
                error "Encryption failed."
                rm -f "$OUTPUT_FILE"
                exit 1
            fi
            ;;
        *)
            error "Internal error: unknown encryption tool '$ENCRYPT_TOOL'."
            exit 1
            ;;
    esac
    chmod 600 "$OUTPUT_FILE"
    success "Encrypted backup saved to '$OUTPUT_FILE' (mode 0600)"
else
    mv "$TEMP_TAR" "$OUTPUT_FILE"
    chmod 600 "$OUTPUT_FILE"
    success "Backup saved to '$OUTPUT_FILE' (mode 0600)"
fi

printf "\n%bBackup completed successfully.%b\n\n" "${BOLD}${GREEN}" "$NC"
