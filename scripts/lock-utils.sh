#!/usr/bin/env bash
# Shared helpers for reading pin files and verifying checksums.
# Sourced by install.sh and scripts/update-locks.sh.

verify_sha256() {
    local file="$1"
    local expected="$2"
    local actual=""

    if command -v sha256sum >/dev/null 2>&1; then
        actual="$(sha256sum "$file" | awk '{print $1}')"
    elif command -v shasum >/dev/null 2>&1; then
        actual="$(shasum -a 256 "$file" | awk '{print $1}')"
    else
        echo "error: sha256sum or shasum is required to verify checksums" >&2
        return 1
    fi

    if [[ "$actual" != "$expected" ]]; then
        echo "error: SHA-256 mismatch for '$file'" >&2
        echo "  expected: $expected" >&2
        echo "  actual:   $actual" >&2
        return 1
    fi
}

os_triple() {
    local sys arch
    sys="$(uname -s)"
    arch="$(uname -m)"
    case "${sys}-${arch}" in
        Linux-x86_64) echo linux-x64 ;;
        Linux-aarch64 | Linux-arm64) echo linux-arm64 ;;
        Darwin-x86_64) echo macos-x64 ;;
        Darwin-arm64) echo macos-arm64 ;;
        *)
            echo "error: unsupported platform ${sys}-${arch}" >&2
            return 1
            ;;
    esac
}

# Reads locks/bootstrap.lock into caller-scoped variables:
#   LOCK_MISE_VERSION LOCK_FONT_TAG LOCK_FONT_ASSET LOCK_FONT_SHA256
#   LOCK_MISE_SHA256_<triple with underscores>
load_bootstrap_lock() {
    local file="$1"
    local key value

    if [[ ! -f "$file" ]]; then
        echo "error: missing bootstrap lock '$file'" >&2
        return 1
    fi

    LOCK_MISE_VERSION=""
    LOCK_FONT_TAG=""
    LOCK_FONT_ASSET=""
    LOCK_FONT_SHA256=""
    LOCK_MISE_SHA256_linux_x64=""
    LOCK_MISE_SHA256_linux_arm64=""
    LOCK_MISE_SHA256_macos_x64=""
    LOCK_MISE_SHA256_macos_arm64=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        key="${line%%=*}"
        value="${line#*=}"
        case "$key" in
            mise_version) LOCK_MISE_VERSION="$value" ;;
            font_tag) LOCK_FONT_TAG="$value" ;;
            font_asset) LOCK_FONT_ASSET="$value" ;;
            font_sha256) LOCK_FONT_SHA256="$value" ;;
            mise_sha256_linux_x64) LOCK_MISE_SHA256_linux_x64="$value" ;;
            mise_sha256_linux_arm64) LOCK_MISE_SHA256_linux_arm64="$value" ;;
            mise_sha256_macos_x64) LOCK_MISE_SHA256_macos_x64="$value" ;;
            mise_sha256_macos_arm64) LOCK_MISE_SHA256_macos_arm64="$value" ;;
            *)
                echo "error: unknown bootstrap lock key '$key'" >&2
                return 1
                ;;
        esac
    done <"$file"

    if [[ -z "$LOCK_MISE_VERSION" || -z "$LOCK_FONT_TAG" || -z "$LOCK_FONT_ASSET" || -z "$LOCK_FONT_SHA256" ]]; then
        echo "error: incomplete bootstrap lock '$file'" >&2
        return 1
    fi
}

mise_sha256_for_triple() {
    local triple="$1"
    case "$triple" in
        linux-x64) printf '%s' "$LOCK_MISE_SHA256_linux_x64" ;;
        linux-arm64) printf '%s' "$LOCK_MISE_SHA256_linux_arm64" ;;
        macos-x64) printf '%s' "$LOCK_MISE_SHA256_macos_x64" ;;
        macos-arm64) printf '%s' "$LOCK_MISE_SHA256_macos_arm64" ;;
        *) return 1 ;;
    esac
}
