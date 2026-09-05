#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$DOTFILES_DIR/scripts/lib.sh"

# Keep in sync with restore.sh ALLOWED_PREFIXES
CANDIDATES=(
    ".ssh/keys"
    ".ssh/config.local"
    ".ssh/conf.d"
    ".config/git/config.local"
    ".config/zsh/local.zsh"
)

# openssl enc does not store iter; restore tries 600000 then 10000.
OPENSSL_ITER=600000

usage() {
    cat <<'EOF'
Usage: backup.sh [--plain] [output_path]

  --plain    Skip encryption. The archive will contain SSH private keys.
  -h, --help Show this help

Encryption is on by default. age is preferred; OpenSSL AES-256-CBC with
PBKDF2 is used when age is not installed. Set DOTFILES_OPENSSL_PASS_FILE
to a passphrase file for non-interactive OpenSSL encryption.
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
            error "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            if [[ -n "$OUTPUT_FILE" ]]; then
                error "Unexpected extra argument: $1"
                usage
                exit 1
            fi
            OUTPUT_FILE="$1"
            shift
            ;;
    esac
done

printf "\n%b=== Backup ===%b\n" "${BOLD}${BLUE}" "$NC"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
DEFAULT_OUT_DIR="$HOME"

section "Scan"

TARGETS=()
for item in "${CANDIDATES[@]}"; do
    if [[ -e "$HOME/$item" ]]; then
        TARGETS+=("$item")
    fi
done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
    warn "No secrets or SSH keys found to back up."
    exit 0
fi

info "Archiving:"
for target in "${TARGETS[@]}"; do
    printf "    %b•%b %s\n" "$CYAN" "$NC" "$HOME/$target"
done

section "Output"

OPENSSL_PASS_FILE="${DOTFILES_OPENSSL_PASS_FILE:-}"

ENCRYPT=true
if [[ "$PLAIN" == true ]]; then
    ENCRYPT=false
elif [[ -n "$OPENSSL_PASS_FILE" ]]; then
    ENCRYPT=true
elif [[ -t 0 ]]; then
    read -r -p "  Encrypt archive with a password? [Y/n]: " encrypt_choice
    if [[ "${encrypt_choice:-}" =~ ^[Nn] ]]; then
        ENCRYPT=false
    fi
else
    error "Encryption requires a terminal, --plain, or DOTFILES_OPENSSL_PASS_FILE."
    exit 1
fi

ENCRYPT_TOOL=""
DEFAULT_ARCHIVE_NAME="dotfiles-backup-${TIMESTAMP}.tar.gz"

if [[ "$ENCRYPT" == true ]]; then
    if [[ -n "$OPENSSL_PASS_FILE" ]]; then
        if [[ ! -f "$OPENSSL_PASS_FILE" ]]; then
            error "Passphrase file not found: $OPENSSL_PASS_FILE"
            exit 1
        fi
        if ! command -v openssl >/dev/null 2>&1; then
            error "openssl was not found."
            exit 1
        fi
        ENCRYPT_TOOL="openssl"
        DEFAULT_ARCHIVE_NAME="${DEFAULT_ARCHIVE_NAME}.enc"
        info "Encrypting with OpenSSL AES-256-CBC, PBKDF2 ${OPENSSL_ITER} iterations"
    elif command -v age >/dev/null 2>&1; then
        ENCRYPT_TOOL="age"
        DEFAULT_ARCHIVE_NAME="${DEFAULT_ARCHIVE_NAME}.age"
        info "Encrypting with age"
    elif command -v openssl >/dev/null 2>&1; then
        ENCRYPT_TOOL="openssl"
        DEFAULT_ARCHIVE_NAME="${DEFAULT_ARCHIVE_NAME}.enc"
        info "Encrypting with OpenSSL AES-256-CBC, PBKDF2 ${OPENSSL_ITER} iterations"
        warn "Install age if you want authenticated encryption."
    else
        error "age or openssl is required to encrypt. Install one of them, or pass --plain."
        exit 1
    fi
else
    warn "Writing an unencrypted archive. It will contain SSH private keys."
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
    info "Encrypting archive"
    case "$ENCRYPT_TOOL" in
        age)
            if ! age -p -o "$OUTPUT_FILE" "$TEMP_TAR"; then
                error "Encryption failed."
                rm -f "$OUTPUT_FILE"
                exit 1
            fi
            ;;
        openssl)
            openssl_args=(-aes-256-cbc -pbkdf2 -iter "$OPENSSL_ITER" -salt -in "$TEMP_TAR" -out "$OUTPUT_FILE")
            if [[ -n "$OPENSSL_PASS_FILE" ]]; then
                openssl_args+=(-pass "file:${OPENSSL_PASS_FILE}")
            fi
            if ! openssl enc "${openssl_args[@]}"; then
                error "Encryption failed."
                rm -f "$OUTPUT_FILE"
                exit 1
            fi
            ;;
        *)
            error "Unknown encryption tool: $ENCRYPT_TOOL"
            exit 1
            ;;
    esac
    chmod 600 "$OUTPUT_FILE"
    success "Saved to $OUTPUT_FILE"
else
    mv "$TEMP_TAR" "$OUTPUT_FILE"
    chmod 600 "$OUTPUT_FILE"
    success "Saved to $OUTPUT_FILE"
fi

printf "\n%bBackup complete.%b\n\n" "${BOLD}${GREEN}" "$NC"
