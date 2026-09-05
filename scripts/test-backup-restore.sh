#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTHOME="$(mktemp -d)"
RESTOREHOME="$(mktemp -d)"
trap 'rm -rf "$TESTHOME" "$RESTOREHOME"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

pass() {
    echo "OK $*"
}

export HOME="$TESTHOME"
mkdir -p "$HOME/.ssh/keys/personal" "$HOME/.config/git" "$HOME/.config/zsh"
echo "secret-key" >"$HOME/.ssh/keys/personal/id_ed25519"
echo "[user]" >"$HOME/.config/git/config.local"
echo "    name = Test" >>"$HOME/.config/git/config.local"
echo "# local" >"$HOME/.config/zsh/local.zsh"

"$ROOT/backup.sh" --plain "$TESTHOME/good.tar.gz" >/dev/null
tar -tzf "$TESTHOME/good.tar.gz" | grep -q ".ssh/keys" || fail "plain backup missing keys"
pass "backup --plain"

export HOME="$RESTOREHOME"
"$ROOT/restore.sh" --yes "$TESTHOME/good.tar.gz" >/dev/null
[[ -f "$HOME/.ssh/keys/personal/id_ed25519" ]] || fail "restore did not write key"
[[ -f "$HOME/.config/git/config.local" ]] || fail "restore did not write git config.local"
perm="$(stat -c '%a' "$HOME/.ssh/keys/personal/id_ed25519")"
[[ "$perm" == "600" ]] || fail "restored key mode is $perm, expected 600"
pass "restore allowlisted archive"

EVILDIR="$TESTHOME/evil"
mkdir -p "$EVILDIR/.ssh/keys"
echo k >"$EVILDIR/.ssh/keys/id"
echo pwned >"$EVILDIR/pwned.txt"
tar -czf "$TESTHOME/evil.tar.gz" -C "$EVILDIR" .ssh/keys pwned.txt
if "$ROOT/restore.sh" --yes "$TESTHOME/evil.tar.gz" >/dev/null 2>&1; then
    fail "restore accepted extra member pwned.txt"
fi
pass "restore rejected extra member"

mkdir -p "$TESTHOME/trav/.ssh/keys"
echo k >"$TESTHOME/trav/.ssh/keys/id"
tar -czf "$TESTHOME/trav.tar.gz" -C "$TESTHOME/trav/.ssh/keys" --transform='s,^,../../,' id
if "$ROOT/restore.sh" --yes "$TESTHOME/trav.tar.gz" >/dev/null 2>&1; then
    fail "restore accepted .. member"
fi
pass "restore rejected path traversal"

mkdir -p "$TESTHOME/sym/.ssh/keys"
ln -s /etc/passwd "$TESTHOME/sym/.ssh/keys/id_ed25519"
tar -czf "$TESTHOME/sym.tar.gz" -C "$TESTHOME/sym" .ssh/keys
if "$ROOT/restore.sh" --yes "$TESTHOME/sym.tar.gz" >/dev/null 2>&1; then
    fail "restore accepted symlink member"
fi
pass "restore rejected symlink"

if "$ROOT/restore.sh" "$TESTHOME/good.tar.gz" </dev/null >/dev/null 2>&1; then
    fail "restore without TTY/--yes succeeded"
fi
pass "restore refuses non-interactive without --yes"

if command -v openssl >/dev/null 2>&1; then
    printf 'ci-test-passphrase\n' >"$TESTHOME/passfile"
    chmod 600 "$TESTHOME/passfile"
    export HOME="$TESTHOME"
    DOTFILES_OPENSSL_PASS_FILE="$TESTHOME/passfile" \
        "$ROOT/backup.sh" "$TESTHOME/good.tar.gz.enc" >/dev/null
    [[ -f "$TESTHOME/good.tar.gz.enc" ]] || fail "encrypted backup was not created"
    RT="$TESTHOME/rthome"
    mkdir -p "$RT"
    export HOME="$RT"
    DOTFILES_OPENSSL_PASS_FILE="$TESTHOME/passfile" \
        "$ROOT/restore.sh" --yes "$TESTHOME/good.tar.gz.enc" >/dev/null
    [[ -f "$HOME/.ssh/keys/personal/id_ed25519" ]] || fail "encrypted restore did not write key"
    pass "openssl encrypt/decrypt round-trip"
else
    echo "notice: openssl was not found; skipped the encryption round-trip"
fi

echo
echo "ALL BACKUP/RESTORE TESTS PASSED"
