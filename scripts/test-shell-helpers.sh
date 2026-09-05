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
    [[ "$plugin_sha" =~ ^[0-9a-f]{7,40}$ ]] || fail "invalid plugin SHA for $plugin_name: '$plugin_sha'"
    [[ "$plugin_url" == https://* ]] || fail "invalid plugin URL for $plugin_name: '$plugin_url'"
    n=$((n + 1))
done <"$ROOT/locks/zsh-plugins.lock"
[[ "$n" -ge 1 ]] || fail "no plugins parsed from zsh-plugins.lock"
pass "parsed $n plugin lock entries"

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

# uninstall shell restore
TESTHOME="$(mktemp -d)"
trap 'rm -rf "$WORKDIR" "$TESTHOME"' EXIT
export HOME="$TESTHOME"
export XDG_STATE_HOME="$TESTHOME/state"
export XDG_CONFIG_HOME="$TESTHOME/config"
export XDG_DATA_HOME="$TESTHOME/data"
mkdir -p "$XDG_STATE_HOME/dotfiles"
printf '%s\n' "/bin/sh" >"$XDG_STATE_HOME/dotfiles/previous-shell"
log="$TESTHOME/uninstall.log"
if ! DOTFILES_SKIP_CHSH=1 "$ROOT/uninstall.sh" >"$log" 2>&1; then
    cat "$log" >&2
    fail "uninstall.sh exited non-zero"
fi
grep -q "would restore /bin/sh" "$log" || {
    cat "$log" >&2
    fail "uninstall did not report restoring the saved shell"
}
[[ ! -f "$XDG_STATE_HOME/dotfiles/previous-shell" ]] || fail "previous-shell file was not consumed"
pass "uninstall restores the saved login shell"

echo
echo "ALL SHELL HELPER TESTS PASSED"
