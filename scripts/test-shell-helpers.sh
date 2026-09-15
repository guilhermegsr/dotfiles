#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

pass() {
    echo "OK $*"
}

n=0
while read -r plugin_name plugin_url plugin_sha _plugin_branch; do
    [[ -z "${plugin_name:-}" || "$plugin_name" == \#* ]] && continue
    [[ "$plugin_sha" =~ ^[0-9a-f]{40}$ ]] || fail "invalid plugin SHA for $plugin_name: '$plugin_sha'"
    [[ "$plugin_url" == https://* ]] || fail "invalid plugin URL for $plugin_name: '$plugin_url'"
    n=$((n + 1))
done <"$ROOT/locks/zsh-plugins.lock"
[[ "$n" -ge 1 ]] || fail "no plugins parsed from zsh-plugins.lock"
pass "parsed $n plugin lock entries"

starship_config="$(zsh -c "
unset STARSHIP_CONFIG
source '$ROOT/zsh/integrations/starship.zsh'
print -r -- \"\$STARSHIP_CONFIG\"
")"
[[ "$starship_config" == "$ROOT/starship/starship.toml" ]] || fail "Starship config resolved to '$starship_config'"
pass "Starship integration resolves the versioned config"

local_line="$(grep -n 'local\.zsh' "$ROOT/zsh/.zshrc" | cut -d: -f1)"
first_integration_line="$(grep -n 'source .*integrations/' "$ROOT/zsh/.zshrc" | head -n 1 | cut -d: -f1)"
[[ "$local_line" -lt "$first_integration_line" ]] || fail "local overrides load after an integration"
pass "local overrides load before shell integrations"

help_output="$("$ROOT/install.sh" --help)"
grep -q -- '--offline' <<<"$help_output" || fail "installer help omits --offline"
grep -q -- '--no-chsh' <<<"$help_output" || fail "installer help omits --no-chsh"
"$ROOT/uninstall.sh" --help | grep -q -- '--purge' || fail "uninstaller help omits --purge"
if "$ROOT/install.sh" --invalid-option >/dev/null 2>&1; then
    fail "installer accepted an invalid option"
fi
if "$ROOT/uninstall.sh" --invalid-option >/dev/null 2>&1; then
    fail "uninstaller accepted an invalid option"
fi
pass "install and uninstall validate command-line options"

# Existing symlinks must be preserved and restored.
mkdir -p "$WORKDIR/link-test"
printf '%s\n' original >"$WORKDIR/link-test/original"
printf '%s\n' managed >"$WORKDIR/link-test/managed"
ln -s "$WORKDIR/link-test/original" "$WORKDIR/link-test/dest"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/lock-utils.sh"
link_file "$WORKDIR/link-test/managed" "$WORKDIR/link-test/dest" >/dev/null
backup_link="$(find "$WORKDIR/link-test" -maxdepth 1 -name 'dest.bak.*' -print -quit)"
[[ -n "$backup_link" && -L "$backup_link" ]] || fail "link_file did not preserve existing symlink"
unlink_file "$WORKDIR/link-test/managed" "$WORKDIR/link-test/dest" >/dev/null
restore_latest_backup "$WORKDIR/link-test/dest" >/dev/null
[[ -L "$WORKDIR/link-test/dest" ]] || fail "original symlink was not restored"
[[ "$(readlink "$WORKDIR/link-test/dest")" == "$WORKDIR/link-test/original" ]] || fail "restored symlink has wrong target"
pass "link replacement preserves and restores an existing symlink"

# Directory symlinks owned by another setup must never be replaced implicitly.
GUARDHOME="$WORKDIR/guard-home"
mkdir -p "$GUARDHOME/config" "$GUARDHOME/original-zsh" "$GUARDHOME/data" "$GUARDHOME/state"
ln -s "$GUARDHOME/original-zsh" "$GUARDHOME/config/zsh"
if HOME="$GUARDHOME" XDG_CONFIG_HOME="$GUARDHOME/config" XDG_DATA_HOME="$GUARDHOME/data" \
    XDG_STATE_HOME="$GUARDHOME/state" DOTFILES_SKIP_CHSH=1 "$ROOT/install.sh" >/dev/null 2>&1; then
    fail "installer replaced an unrelated config directory symlink"
fi
[[ -L "$GUARDHOME/config/zsh" ]] || fail "installer removed an unrelated config directory symlink"
[[ "$(readlink "$GUARDHOME/config/zsh")" == "$GUARDHOME/original-zsh" ]] || fail "installer changed an unrelated symlink target"
pass "installer refuses to replace an unrelated config directory symlink"

zsh -c "
set -e
source '$ROOT/zsh/config/functions.zsh'
cd '$WORKDIR'

# myip
got=\$(printf '%s\n' '1.1.1.1 dev eth0 src 192.168.1.10 uid 1000' | _local_ip_from_route)
[[ \$got == 192.168.1.10 ]] || exit 1
got=\$(printf '%s\n' '1.1.1.1 via 192.168.1.1 dev eth0 src 10.0.0.5 uid 1000' | _local_ip_from_route)
[[ \$got == 10.0.0.5 ]] || exit 1

# extract ok
mkdir safe
echo hello > safe/file.txt
tar -czf safe.tar.gz -C safe file.txt
mkdir out && cd out
extract ../safe.tar.gz >/dev/null
[[ -f file.txt ]] || exit 1
cd ..

# extract rejects ..
mkdir trav
echo pwned > trav/id
tar -czf trav.tar.gz -C trav --transform='s,^,../../,' id
if extract trav.tar.gz >/dev/null 2>&1; then
  exit 1
fi
" || fail "zsh helper tests: myip/extract"
pass "myip parses src from ip route"
pass "extract allows a normal tar.gz"
pass "extract refuses .. members"

# pubkey
mkdir -p "$WORKDIR/keys"
ssh-keygen -t ed25519 -N '' -f "$WORKDIR/keys/id_ed25519" -C test >/dev/null
cp "$WORKDIR/keys/id_ed25519" "$WORKDIR/keys/orphan"
zsh -c "
source '$ROOT/zsh/config/functions.zsh'
if pubkey '$WORKDIR/keys/orphan' >/dev/null 2>&1; then
  exit 1
fi
out=\$(pubkey '$WORKDIR/keys/id_ed25519' 2>/dev/null)
printf '%s\n' \"\$out\" | grep -q '^ssh-ed25519 '
printf '%s\n' \"\$out\" | grep -qv 'PRIVATE KEY'
" || fail "pubkey tests"
pass "pubkey refuses a private key without .pub"
pass "pubkey copies companion .pub only"

LEGACYHOME="$WORKDIR/legacy-home"
mkdir -p "$LEGACYHOME/.ssh"
cp "$WORKDIR/keys/id_ed25519.pub" "$LEGACYHOME/.ssh/id_ed25519.pub"
HOME="$LEGACYHOME" zsh -c "
source '$ROOT/zsh/config/functions.zsh'
if pubkey work >/dev/null 2>&1; then
  exit 1
fi
pubkey personal >/dev/null 2>&1
" || fail "pubkey target fallback tests"
pass "pubkey does not substitute a personal key for a missing named key"

IMPORTHOME="$WORKDIR/import-home"
mkdir -p "$IMPORTHOME"
HOME="$IMPORTHOME" zsh -c "
source '$ROOT/zsh/config/functions.zsh'
ssh-import '$WORKDIR/keys/id_ed25519.pub' servers >/dev/null
" || fail "ssh-import public key"
[[ -f "$IMPORTHOME/.ssh/keys/servers/id_ed25519.pub" ]] || fail "ssh-import did not store public key"
[[ ! -e "$IMPORTHOME/.ssh/keys/servers/id_ed25519.pub.pub" ]] || fail "ssh-import created .pub.pub"
imported_mode="$(stat -c '%a' "$IMPORTHOME/.ssh/keys/servers/id_ed25519.pub")"
[[ "$imported_mode" == "644" ]] || fail "imported public key mode is $imported_mode, expected 644"
pass "ssh-import handles a public key without creating .pub.pub"

# Offline installation and uninstall shell restore
TESTHOME="$(mktemp -d)"
trap 'rm -rf "$WORKDIR" "$TESTHOME"' EXIT
export HOME="$TESTHOME"
export XDG_STATE_HOME="$TESTHOME/state"
export XDG_CONFIG_HOME="$TESTHOME/config"
export XDG_DATA_HOME="$TESTHOME/data"

install_log="$TESTHOME/install.log"
if ! "$ROOT/install.sh" --offline --no-chsh >"$install_log" 2>&1; then
    cat "$install_log" >&2
    fail "offline install exited non-zero"
fi
grep -q "Offline mode" "$install_log" || fail "offline install did not report its mode"
[[ -L "$XDG_CONFIG_HOME/starship.toml" ]] || fail "offline install did not link Starship config"
[[ ! -e "$HOME/.local/bin/mise" ]] || fail "offline install provisioned Mise"
[[ ! -d "$XDG_DATA_HOME/zsh/plugins/zsh-autosuggestions/.git" ]] || fail "offline install downloaded plugins"
pass "offline install deploys configs without provisioning tools"

doctor_log="$TESTHOME/doctor.log"
if ! "$ROOT/scripts/doctor.sh" >"$doctor_log" 2>&1; then
    cat "$doctor_log" >&2
    fail "doctor reported errors after an offline install"
fi
grep -q '0 errors' "$doctor_log" || fail "doctor did not report a clean result"
pass "doctor validates an installed configuration without changing it"

mkdir -p "$XDG_STATE_HOME/dotfiles"
mkdir -p "$XDG_CONFIG_HOME/mise"
printf '%s\n' "/bin/sh" >"$XDG_STATE_HOME/dotfiles/previous-shell"
ln -s "$ROOT/mise/mise.lock" "$XDG_CONFIG_HOME/mise/mise.lock"

managed_plugin="$XDG_DATA_HOME/zsh/plugins/managed-test"
mkdir -p "$managed_plugin"
git -C "$managed_plugin" init --quiet
git -C "$managed_plugin" config user.name Test
git -C "$managed_plugin" config user.email test@example.com
printf '%s\n' managed >"$managed_plugin/plugin.zsh"
git -C "$managed_plugin" add plugin.zsh
git -C "$managed_plugin" commit --quiet -m initial
git -C "$managed_plugin" remote add origin https://example.com/managed-test.git
printf '%s\t%s\n' managed-test https://example.com/managed-test.git >"$XDG_STATE_HOME/dotfiles/installed-plugins"

dirty_plugin="$XDG_DATA_HOME/zsh/plugins/dirty-test"
mkdir -p "$dirty_plugin"
git -C "$dirty_plugin" init --quiet
git -C "$dirty_plugin" config user.name Test
git -C "$dirty_plugin" config user.email test@example.com
printf '%s\n' original >"$dirty_plugin/plugin.zsh"
git -C "$dirty_plugin" add plugin.zsh
git -C "$dirty_plugin" commit --quiet -m initial
git -C "$dirty_plugin" remote add origin https://example.com/dirty-test.git
printf '%s\n' changed >"$dirty_plugin/plugin.zsh"
printf '%s\t%s\n' dirty-test https://example.com/dirty-test.git >>"$XDG_STATE_HOME/dotfiles/installed-plugins"

mkdir -p "$XDG_DATA_HOME/zsh/plugins/user-plugin"
printf '%s\n' preserve >"$XDG_DATA_HOME/zsh/plugins/user-plugin/file"

mkdir -p "$HOME/.local/bin"
printf '%s\n' '#!/bin/sh' 'echo "1.2.3 linux-x64"' >"$HOME/.local/bin/mise"
chmod 755 "$HOME/.local/bin/mise"
managed_mise_sha="$(sha256_file "$HOME/.local/bin/mise")"
printf 'path=%s\nversion=1.2.3\nsha256=%s\n' "$HOME/.local/bin/mise" "$managed_mise_sha" >"$XDG_STATE_HOME/dotfiles/managed-mise"

mkdir -p "$XDG_DATA_HOME/fonts"
printf '%s\n' preexisting >"$XDG_DATA_HOME/fonts/JetBrainsMonoNerd-Preexisting.ttf"
printf '%s\n' managed >"$XDG_DATA_HOME/fonts/JetBrainsMonoNerd-Managed.ttf"
printf '%s\n' JetBrainsMonoNerd-Managed.ttf >"$XDG_STATE_HOME/dotfiles/installed-fonts"
log="$TESTHOME/uninstall.log"
if ! DOTFILES_SKIP_CHSH=1 "$ROOT/uninstall.sh" --purge >"$log" 2>&1; then
    cat "$log" >&2
    fail "uninstall.sh exited non-zero"
fi
grep -q "would restore /bin/sh" "$log" || {
    cat "$log" >&2
    fail "uninstall did not report restoring the saved shell"
}
[[ ! -f "$XDG_STATE_HOME/dotfiles/previous-shell" ]] || fail "previous-shell file was not consumed"
pass "uninstall restores the saved login shell"
[[ ! -L "$XDG_CONFIG_HOME/mise/mise.lock" ]] || fail "uninstall kept the legacy Mise lock symlink"
pass "uninstall removes the legacy Mise lock symlink"
[[ ! -e "$managed_plugin" ]] || fail "purge kept a recorded clean plugin"
[[ -d "$dirty_plugin" ]] || fail "purge removed a plugin with local changes"
[[ -d "$XDG_DATA_HOME/zsh/plugins/user-plugin" ]] || fail "purge removed an unregistered plugin"
[[ ! -e "$HOME/.local/bin/mise" ]] || fail "purge kept the recorded Mise binary"
grep -q '^dirty-test' "$XDG_STATE_HOME/dotfiles/installed-plugins" || fail "purge discarded ownership for a preserved plugin"
! grep -q '^managed-test' "$XDG_STATE_HOME/dotfiles/installed-plugins" || fail "purge retained ownership for a removed plugin"
pass "purge removes only recorded plugins and Mise artifacts"
[[ -f "$XDG_DATA_HOME/fonts/JetBrainsMonoNerd-Preexisting.ttf" ]] || fail "uninstall removed a preexisting font"
[[ ! -e "$XDG_DATA_HOME/fonts/JetBrainsMonoNerd-Managed.ttf" ]] || fail "uninstall kept a managed font"
pass "uninstall removes only fonts recorded in its manifest"

echo
echo "ALL SHELL HELPER TESTS PASSED"
