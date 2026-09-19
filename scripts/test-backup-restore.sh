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

printf '%s\n' "keep-existing" >"$TESTHOME/existing.tar.gz"
if "$ROOT/backup.sh" --plain "$TESTHOME/existing.tar.gz" >/dev/null 2>&1; then
    fail "backup replaced an existing output without --force"
fi
grep -q '^keep-existing$' "$TESTHOME/existing.tar.gz" || fail "existing backup output was modified"
"$ROOT/backup.sh" --plain --force "$TESTHOME/existing.tar.gz" >/dev/null
tar -tzf "$TESTHOME/existing.tar.gz" >/dev/null || fail "backup --force did not write an archive"
pass "backup refuses overwrite unless --force is passed"

# Partial archives of the secrets must not pile up unnoticed.
stale_stage="$TESTHOME/.dotfiles-backup.stale1"
fresh_stage="$TESTHOME/.dotfiles-backup.fresh1"
mkdir -p "$stale_stage" "$fresh_stage"
printf 'parcial\n' >"$stale_stage/archive"
touch -d '2 days ago' "$stale_stage"
"$ROOT/backup.sh" --plain --force "$TESTHOME/sweep.tar.gz" >/dev/null
[[ ! -e "$stale_stage" ]] || fail "backup kept a stale staging directory"
[[ -d "$fresh_stage" ]] || fail "backup removed a staging directory that may still be in use"
rm -rf "$fresh_stage"
pass "backup sweeps staging directories left by an interrupted run"

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

mkdir -p "$TESTHOME/fifo/.ssh/keys"
mkfifo "$TESTHOME/fifo/.ssh/keys/blocked"
tar -czf "$TESTHOME/fifo.tar.gz" -C "$TESTHOME/fifo" .ssh/keys
if "$ROOT/restore.sh" --yes "$TESTHOME/fifo.tar.gz" >/dev/null 2>&1; then
    fail "restore accepted FIFO member"
fi
pass "restore rejected non-regular member"

# cp writes through a symlink sitting at the destination.
SYMHOME="$(mktemp -d)"
mkdir -p "$SYMHOME/.config/git" "$SYMHOME/elsewhere"
printf '%s\n' original >"$SYMHOME/elsewhere/target"
ln -s "$SYMHOME/elsewhere/target" "$SYMHOME/.config/git/config.local"
if HOME="$SYMHOME" "$ROOT/restore.sh" --yes "$TESTHOME/good.tar.gz" >/dev/null 2>&1; then
    fail "restore wrote through a symlink in HOME"
fi
grep -qx original "$SYMHOME/elsewhere/target" || fail "restore modified a symlink target"
rm -rf "$SYMHOME"
pass "restore refuses to write through a symlink already in HOME"

if "$ROOT/restore.sh" "$TESTHOME/good.tar.gz" </dev/null >/dev/null 2>&1; then
    fail "restore without TTY/--yes succeeded"
fi
pass "restore refuses non-interactive without --yes"

# The machine being restored onto may be the last place that key exists.
CLOBBERHOME="$(mktemp -d)"
mkdir -p "$CLOBBERHOME/.ssh/keys/personal"
printf '%s\n' existing-key >"$CLOBBERHOME/.ssh/keys/personal/id_ed25519"
HOME="$CLOBBERHOME" "$ROOT/restore.sh" --yes "$TESTHOME/good.tar.gz" >/dev/null
grep -qx secret-key "$CLOBBERHOME/.ssh/keys/personal/id_ed25519" \
    || fail "restore did not write the archived key"
kept="$(find "$CLOBBERHOME/.ssh/keys/personal" -name 'id_ed25519.bak.*' | head -n 1)"
[[ -n "$kept" ]] || fail "restore replaced an existing key without keeping a copy"
grep -qx existing-key "$kept" || fail "the copy restore kept is not the previous key"
rm -rf "$CLOBBERHOME"
pass "restore keeps a copy of every secret it replaces"

# tar would store the link, not the key: an archive that restores nothing.
LINKHOME="$(mktemp -d)"
mkdir -p "$LINKHOME/.ssh/keys/personal" "$LINKHOME/vault"
printf '%s\n' vault-key >"$LINKHOME/vault/id_ed25519"
ln -s "$LINKHOME/vault/id_ed25519" "$LINKHOME/.ssh/keys/personal/id_ed25519"
HOME="$LINKHOME" "$ROOT/backup.sh" --plain "$LINKHOME/linked.tar.gz" >/dev/null
if LC_ALL=C tar -tvzf "$LINKHOME/linked.tar.gz" | grep -q '^l'; then
    fail "backup stored a symbolic link instead of the key behind it"
fi
LINKRESTORE="$(mktemp -d)"
HOME="$LINKRESTORE" "$ROOT/restore.sh" --yes "$LINKHOME/linked.tar.gz" >/dev/null
grep -qx vault-key "$LINKRESTORE/.ssh/keys/personal/id_ed25519" \
    || fail "restore did not recover the key that lived behind a symlink"
rm -rf "$LINKHOME" "$LINKRESTORE"
pass "backup follows a symlinked key so the archive can be restored"

DANGLEHOME="$(mktemp -d)"
mkdir -p "$DANGLEHOME/.ssh/keys/personal"
ln -s "$DANGLEHOME/vault/missing" "$DANGLEHOME/.ssh/keys/personal/id_ed25519"
if HOME="$DANGLEHOME" "$ROOT/backup.sh" --plain "$DANGLEHOME/dangling.tar.gz" >/dev/null 2>&1; then
    fail "backup wrote an archive built from a dangling symlink"
fi
[[ ! -e "$DANGLEHOME/dangling.tar.gz" ]] || fail "backup left an archive behind after refusing"
rm -rf "$DANGLEHOME"
pass "backup refuses a key symlink that points nowhere"

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

if command -v age >/dev/null 2>&1; then
    export HOME="$TESTHOME"
    mkdir -p "$HOME/.ssh/keys/personal"
    ssh-keygen -q -t ed25519 -N '' -f "$HOME/.ssh/keys/personal/id_ed25519" <<<y >/dev/null 2>&1
    ssh-keygen -q -t ed25519 -N '' -f "$TESTHOME/spare" >/dev/null 2>&1
    cat "$TESTHOME/spare.pub" >"$HOME/.ssh/age-recipients"

    age_log="$TESTHOME/age-backup.log"
    "$ROOT/backup.sh" "$TESTHOME/keyed.tar.gz" >"$age_log" 2>&1 \
        || { cat "$age_log" >&2; fail "keyed backup failed"; }
    [[ -f "$TESTHOME/keyed.tar.gz.age" ]] || fail "keyed backup produced no .age archive"
    grep -q "id_ed25519.pub" "$age_log" || fail "backup did not report the recipient"

    AGEHOME="$(mktemp -d)"
    mkdir -p "$AGEHOME/.ssh/keys/personal"
    cp "$HOME/.ssh/keys/personal/id_ed25519" "$AGEHOME/.ssh/keys/personal/id_ed25519"
    HOME="$AGEHOME" "$ROOT/restore.sh" --yes "$TESTHOME/keyed.tar.gz.age" </dev/null >/dev/null 2>&1 \
        || fail "restore with the personal key failed"
    [[ -f "$AGEHOME/.ssh/keys/personal/id_ed25519" ]] || fail "restore lost the key it decrypted with"
    grep -q '^# local$' "$AGEHOME/.config/zsh/local.zsh" 2>/dev/null \
        || fail "restore did not write the archived files"

    # The spare recipient is a second, independent way in.
    SPAREHOME="$(mktemp -d)"
    HOME="$SPAREHOME" DOTFILES_AGE_IDENTITY="$TESTHOME/spare" \
        "$ROOT/restore.sh" --yes "$TESTHOME/keyed.tar.gz.age" </dev/null >/dev/null 2>&1 \
        || fail "restore with the spare recipient failed"
    [[ -f "$SPAREHOME/.config/zsh/local.zsh" ]] || fail "spare restore wrote nothing"

    ssh-keygen -q -t ed25519 -N '' -f "$TESTHOME/outsider" >/dev/null 2>&1
    OUTHOME="$(mktemp -d)"
    if HOME="$OUTHOME" DOTFILES_AGE_IDENTITY="$TESTHOME/outsider" \
        "$ROOT/restore.sh" --yes "$TESTHOME/keyed.tar.gz.age" </dev/null >/dev/null 2>&1; then
        fail "restore accepted a key that is not a recipient"
    fi

    rm -rf "$AGEHOME" "$SPAREHOME" "$OUTHOME"
    pass "age backup encrypts to the SSH key and restores without a passphrase"
else
    echo "SKIP age recipient round-trip (age is not installed)"
fi
else
    echo "notice: openssl was not found; skipped the encryption round-trip"
fi

echo
echo "ALL BACKUP/RESTORE TESTS PASSED"
