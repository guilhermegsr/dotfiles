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

# The machine this restores onto is being rebuilt, so a passphrase from
# months ago is the likeliest thing to be missing. age cannot mix -R with
# -p, which makes a spare key the only second way in.
DEFAULT_RECIPIENT="$HOME/.ssh/keys/personal/id_ed25519.pub"
EXTRA_RECIPIENTS="${DOTFILES_AGE_RECIPIENTS:-$HOME/.ssh/age-recipients}"

usage() {
    cat <<'EOF'
Usage: backup.sh [--plain] [--passphrase] [--force] [output_path]

  --plain      Skip encryption. The archive will contain SSH private keys.
  --passphrase Encrypt to a passphrase instead of to your SSH key.
  --force      Replace an existing output file.
  -h, --help   Show this help

Encryption is on by default. With age installed, the archive is encrypted to
your public key at ~/.ssh/keys/personal/id_ed25519.pub, so restoring needs
the matching private key and no passphrase. Add more public keys to
~/.ssh/age-recipients (or point DOTFILES_AGE_RECIPIENTS at a file) to keep a
second way in. Without age, or with --passphrase, OpenSSL AES-256-CBC with
PBKDF2 is used; set DOTFILES_OPENSSL_PASS_FILE for a non-interactive run.
EOF
}

PLAIN=false
PASSPHRASE=false
FORCE=false
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --plain)
            PLAIN=true
            shift
            ;;
        --passphrase)
            PASSPHRASE=true
            shift
            ;;
        --force)
            FORCE=true
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

# tar would store the link and not the key behind it, which restore.sh then
# rejects: an archive that looks fine and holds nothing.
SYMLINKED_MEMBERS=()
DANGLING_MEMBERS=()
for item in "${TARGETS[@]}"; do
    while IFS= read -r -d '' link; do
        if [[ -e "$link" ]]; then
            SYMLINKED_MEMBERS+=("${link#"$HOME/"}")
        else
            DANGLING_MEMBERS+=("${link#"$HOME/"}")
        fi
    done < <(find "$HOME/$item" -type l -print0 2>/dev/null)
done

if [[ ${#DANGLING_MEMBERS[@]} -gt 0 ]]; then
    error "These are symbolic links that point nowhere:"
    for member in "${DANGLING_MEMBERS[@]}"; do
        printf "    %b•%b %s\n" "$RED" "$NC" "$HOME/$member"
    done
    error "An archive built from them would hold no key. Fix or remove them."
    exit 1
fi

if [[ ${#SYMLINKED_MEMBERS[@]} -gt 0 ]]; then
    warn "Following these symbolic links; the archive stores their contents:"
    for member in "${SYMLINKED_MEMBERS[@]}"; do
        printf "    %b•%b %s\n" "$YELLOW" "$NC" "$HOME/$member"
    done
fi

section "Output"

OPENSSL_PASS_FILE="${DOTFILES_OPENSSL_PASS_FILE:-}"

ENCRYPT_TOOL=""
AGE_RECIPIENT_ARGS=()
DEFAULT_ARCHIVE_NAME="dotfiles-backup-${TIMESTAMP}.tar.gz"

collect_age_recipients() {
    AGE_RECIPIENT_ARGS=()
    if [[ -f "$DEFAULT_RECIPIENT" ]]; then
        AGE_RECIPIENT_ARGS+=(-R "$DEFAULT_RECIPIENT")
    fi
    if [[ -f "$EXTRA_RECIPIENTS" ]]; then
        AGE_RECIPIENT_ARGS+=(-R "$EXTRA_RECIPIENTS")
    fi
    [[ ${#AGE_RECIPIENT_ARGS[@]} -gt 0 ]]
}

# No prompt and no secret to type, which is what allows an unattended backup.
KEY_ENCRYPTION=false
if [[ "$PASSPHRASE" == false && -z "$OPENSSL_PASS_FILE" ]] \
    && command -v age >/dev/null 2>&1 && collect_age_recipients; then
    KEY_ENCRYPTION=true
fi

ENCRYPT=true
if [[ "$PLAIN" == true ]]; then
    ENCRYPT=false
elif [[ "$KEY_ENCRYPTION" == true || -n "$OPENSSL_PASS_FILE" ]]; then
    ENCRYPT=true
elif [[ -t 0 ]]; then
    read -r -p "  Encrypt archive with a password? [Y/n]: " encrypt_choice
    if [[ "${encrypt_choice:-}" =~ ^[Nn] ]]; then
        ENCRYPT=false
    fi
else
    error "Encryption needs a recipient key, a terminal, --plain, or DOTFILES_OPENSSL_PASS_FILE."
    exit 1
fi

if [[ "$ENCRYPT" == true ]]; then
    if [[ "$KEY_ENCRYPTION" == true ]]; then
        ENCRYPT_TOOL="age-recipients"
        DEFAULT_ARCHIVE_NAME="${DEFAULT_ARCHIVE_NAME}.age"
        info "Encrypting with age to:"
        for recipient_arg in "${AGE_RECIPIENT_ARGS[@]}"; do
            [[ "$recipient_arg" == "-R" ]] && continue
            printf "    %b•%b %s\n" "$CYAN" "$NC" "$recipient_arg"
        done
        if [[ ! -f "$EXTRA_RECIPIENTS" ]]; then
            info "Add spare public keys to $EXTRA_RECIPIENTS to keep a second way in"
        fi
    elif [[ -n "$OPENSSL_PASS_FILE" ]]; then
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
        info "Encrypting with age, to a passphrase"
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

if [[ "$ENCRYPT" == true && "$ENCRYPT_TOOL" == age* && "$OUTPUT_FILE" != *.age ]]; then
    OUTPUT_FILE="${OUTPUT_FILE}.age"
fi
if [[ "$ENCRYPT" == true && "$ENCRYPT_TOOL" == "openssl" && "$OUTPUT_FILE" != *.enc ]]; then
    OUTPUT_FILE="${OUTPUT_FILE}.enc"
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

if [[ -d "$OUTPUT_FILE" ]]; then
    error "Output path is a directory: $OUTPUT_FILE"
    exit 1
fi

if [[ "$FORCE" != true && ( -e "$OUTPUT_FILE" || -L "$OUTPUT_FILE" ) ]]; then
    error "Output file already exists: $OUTPUT_FILE"
    error "Choose another path or pass --force to replace it."
    exit 1
fi

OUTPUT_DIR="$(dirname "$OUTPUT_FILE")"

sweep_stale_staging "$OUTPUT_DIR" ".dotfiles-backup.*"

OUTPUT_STAGE_DIR="$(mktemp -d "$OUTPUT_DIR/.dotfiles-backup.XXXXXX")"
OUTPUT_TEMP="$OUTPUT_STAGE_DIR/archive"

# tar and the encryptor are direct children. Without this they outlive Ctrl-C
# and keep encrypting into a directory the trap has already removed.
cleanup_backup() {
    pkill -P $$ >/dev/null 2>&1 || true
    rm -rf "$OUTPUT_STAGE_DIR"
}
trap cleanup_backup EXIT

stream_archive() {
    tar -czhf - -C "$HOME" "${TARGETS[@]}"
}

# Streamed into the encryptor: the private keys never reach the disk in the
# clear, not even as a leftover if the process is killed before the trap runs.
if [[ "$ENCRYPT" == true ]]; then
    info "Encrypting archive"
    case "$ENCRYPT_TOOL" in
        age-recipients)
            if ! stream_archive | age "${AGE_RECIPIENT_ARGS[@]}" -o "$OUTPUT_TEMP"; then
                error "Encryption failed."
                exit 1
            fi
            ;;
        age)
            if ! stream_archive | age -p -o "$OUTPUT_TEMP"; then
                error "Encryption failed."
                exit 1
            fi
            ;;
        openssl)
            openssl_args=(-aes-256-cbc -pbkdf2 -iter "$OPENSSL_ITER" -salt -out "$OUTPUT_TEMP")
            if [[ -n "$OPENSSL_PASS_FILE" ]]; then
                openssl_args+=(-pass "file:${OPENSSL_PASS_FILE}")
            fi
            if ! stream_archive | openssl enc "${openssl_args[@]}"; then
                error "Encryption failed."
                exit 1
            fi
            ;;
        *)
            error "Unknown encryption tool: $ENCRYPT_TOOL"
            exit 1
            ;;
    esac
else
    stream_archive >"$OUTPUT_TEMP"
fi

chmod 600 "$OUTPUT_TEMP"

# The path may have appeared while the archive was being written.
if [[ "$FORCE" != true && ( -e "$OUTPUT_FILE" || -L "$OUTPUT_FILE" ) ]]; then
    error "Output file appeared while creating the backup: $OUTPUT_FILE"
    error "The new archive was not installed. Pass --force to replace it."
    exit 1
fi

if [[ -d "$OUTPUT_FILE" ]]; then
    error "Output path became a directory while creating the backup: $OUTPUT_FILE"
    exit 1
fi

if [[ "$FORCE" == true && -L "$OUTPUT_FILE" ]]; then
    rm -f "$OUTPUT_FILE"
fi

mv -f "$OUTPUT_TEMP" "$OUTPUT_FILE"
rmdir "$OUTPUT_STAGE_DIR"
success "Saved to $OUTPUT_FILE"

printf "\n%bBackup complete.%b\n\n" "${BOLD}${GREEN}" "$NC"
