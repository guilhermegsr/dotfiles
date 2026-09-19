#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "$ROOT/scripts/lib.sh"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_DIR="$(dotfiles_state_dir)"

doctor_ok_count=0
doctor_warning_count=0
doctor_error_count=0

doctor_ok() {
    success "$1"
    doctor_ok_count=$((doctor_ok_count + 1))
}

doctor_warn() {
    warn "$1"
    doctor_warning_count=$((doctor_warning_count + 1))
}

doctor_fail() {
    error "$1"
    doctor_error_count=$((doctor_error_count + 1))
}

file_mode() {
    local path="$1"
    if stat -c '%a' "$path" >/dev/null 2>&1; then
        stat -c '%a' "$path"
    else
        stat -f '%Lp' "$path"
    fi
}

check_link() {
    local expected="$1"
    local dest="$2"
    if [[ ! -L "$dest" ]]; then
        doctor_fail "Missing managed symlink: $dest"
        return
    fi

    local actual
    actual="$(readlink "$dest")"
    if [[ "$actual" == "$expected" ]]; then
        doctor_ok "Linked: $dest"
    else
        doctor_fail "$dest points to $actual, expected $expected"
    fi
}

check_private_mode() {
    local path="$1"
    local expected="$2"
    local mode
    mode="$(file_mode "$path")"
    if [[ "$mode" == "$expected" ]]; then
        doctor_ok "Permissions $expected: $path"
    else
        doctor_fail "$path has permissions $mode, expected $expected"
    fi
}

printf "\n%b=== Dotfiles Doctor ===%b\n" "${BOLD}${BLUE}" "$NC"
printf "%bRepository: %s%b\n" "$DIM" "$ROOT" "$NC"

section "Repository"
if bash -n "$ROOT/install.sh" "$ROOT/uninstall.sh" "$ROOT/backup.sh" "$ROOT/restore.sh" "$ROOT"/scripts/*.sh "$ROOT"/scripts/install/*.sh "$ROOT"/scripts/uninstall/*.sh; then
    doctor_ok "Bash syntax"
else
    doctor_fail "Bash syntax validation failed"
fi

if command -v zsh >/dev/null 2>&1; then
    if zsh -n "$ROOT/zsh/.zshenv" "$ROOT/zsh/.zshrc" "$ROOT/zsh/local.zsh.example" "$ROOT"/zsh/config/*.zsh "$ROOT"/zsh/integrations/*.zsh; then
        doctor_ok "Zsh syntax"
    else
        doctor_fail "Zsh syntax validation failed"
    fi
else
    doctor_fail "zsh is not installed"
fi

if command -v python3 >/dev/null 2>&1; then
    if ROOT="$ROOT" python3 -c 'import os, pathlib, tomllib; root=pathlib.Path(os.environ["ROOT"]); [tomllib.loads((root/path).read_text()) for path in ("mise/config.toml", "starship/starship.toml")]'; then
        doctor_ok "TOML syntax"
    else
        doctor_fail "TOML syntax validation failed"
    fi
else
    doctor_warn "python3 is unavailable; TOML syntax was not checked"
fi

if git config --file "$ROOT/git/config" --list >/dev/null; then
    doctor_ok "Git configuration parses"
else
    doctor_fail "Git configuration is invalid"
fi

if grep -qE '(/home/|/Users/)' "$ROOT/git/config"; then
    doctor_fail "git/config holds machine-specific paths; move them to $CONFIG_DIR/git/config.local"
else
    doctor_ok "Git configuration is free of machine-specific paths"
fi

section "Managed links"
while IFS=$'\t' read -r expected dest; do
    check_link "$expected" "$dest"
done <<EOF
$ROOT/zsh/.zshrc	$CONFIG_DIR/zsh/.zshrc
$ROOT/zsh/.zshenv	$CONFIG_DIR/zsh/.zshenv
$ROOT/zsh/config	$CONFIG_DIR/zsh/config
$ROOT/zsh/integrations	$CONFIG_DIR/zsh/integrations
$ROOT/zsh/.zshenv	$HOME/.zshenv
$ROOT/git/ignore	$CONFIG_DIR/git/ignore
$ROOT/mise/config.toml	$CONFIG_DIR/mise/config.toml
$ROOT/starship/starship.toml	$CONFIG_DIR/starship.toml
$ROOT/tmux	$CONFIG_DIR/tmux
$ROOT/alacritty	$CONFIG_DIR/alacritty
$ROOT/ssh/config	$HOME/.ssh/config
EOF

git_global_config="$CONFIG_DIR/git/config"
if [[ -L "$git_global_config" ]]; then
    doctor_fail "$git_global_config is a symlink into the repository; run ./install.sh to migrate it"
elif [[ ! -f "$git_global_config" ]]; then
    doctor_fail "Missing global Git config: $git_global_config"
elif ! git config --file "$git_global_config" --get-all include.path 2>/dev/null | grep -qxF "$ROOT/git/config"; then
    doctor_fail "$git_global_config does not include $ROOT/git/config"
elif [[ "$(git config --file "$git_global_config" --includes --get init.defaultBranch 2>/dev/null || true)" != "main" ]]; then
    doctor_fail "Shared Git settings are not reachable through $git_global_config"
else
    doctor_ok "Global Git config is machine-local and includes $ROOT/git/config"
fi

# `gh auth setup-git` rewrites this and wins over config.local, because it
# appends past the includes and an empty value resets the helper list.
credential_helper="$(git config --global --includes --get-all credential."https://github.com".helper 2>/dev/null | tail -n 1 || true)"
case "$credential_helper" in
    "") ;;
    */mise/installs/*)
        doctor_warn "Credential helper pins a Mise install path, so it breaks on the next upgrade: ${credential_helper#!}"
        info "Point it at $DATA_DIR/mise/shims/ from $CONFIG_DIR/git/config.local"
        ;;
    '!'[!/]*)
        doctor_warn "Credential helper depends on PATH, which Git lacks outside an interactive shell: ${credential_helper#!}"
        ;;
    *)
        doctor_ok "Git credential helper is version-independent"
        ;;
esac

for private_config in "$CONFIG_DIR/zsh/local.zsh" "$CONFIG_DIR/git/config.local"; do
    if [[ -f "$private_config" && ! -L "$private_config" ]]; then
        check_private_mode "$private_config" 600
    else
        doctor_fail "Missing regular local config: $private_config"
    fi
done

section "SSH"
for dir in "$HOME/.ssh" "$HOME/.ssh/keys" "$HOME/.ssh/keys/personal" "$HOME/.ssh/keys/work" "$HOME/.ssh/keys/servers" "$HOME/.ssh/sockets" "$HOME/.ssh/conf.d"; do
    if [[ -d "$dir" ]]; then
        check_private_mode "$dir" 700
    else
        doctor_fail "Missing SSH directory: $dir"
    fi
done

if [[ -f "$HOME/.ssh/config.local" && ! -L "$HOME/.ssh/config.local" ]]; then
    check_private_mode "$HOME/.ssh/config.local" 600
else
    doctor_fail "Missing regular SSH override file: $HOME/.ssh/config.local"
fi

if command -v ssh >/dev/null 2>&1 && ssh -G -F "$HOME/.ssh/config" github.com >/dev/null 2>&1; then
    doctor_ok "SSH configuration parses"
else
    doctor_fail "SSH configuration is invalid or ssh is unavailable"
fi

while IFS= read -r -d '' private_key; do
    mode="$(file_mode "$private_key")"
    if [[ "$mode" == 600 || "$mode" == 400 ]]; then
        doctor_ok "Private key permissions: $private_key"
    else
        doctor_fail "$private_key has unsafe permissions $mode"
    fi
done < <(find "$HOME/.ssh/keys" -type f ! -name '*.pub' -print0 2>/dev/null)

section "Runtime"
if command -v mise >/dev/null 2>&1; then
    doctor_ok "Mise: $(mise --version 2>/dev/null | head -n 1)"
else
    doctor_warn "Mise is not installed or not in PATH"
fi

if command -v starship >/dev/null 2>&1; then
    doctor_ok "Starship: $(starship --version 2>/dev/null | head -n 1)"
else
    doctor_warn "Starship is not installed; run mise install when ready"
fi

plugin_manifest="$STATE_DIR/installed-plugins"
plugin_dir="$DATA_DIR/zsh/plugins"
while read -r plugin_name plugin_url plugin_sha _plugin_branch; do
    [[ -z "${plugin_name:-}" || "$plugin_name" == \#* ]] && continue
    checkout="$plugin_dir/$plugin_name"
    if [[ ! -d "$checkout/.git" ]]; then
        doctor_warn "Plugin is not installed: $plugin_name"
        continue
    fi
    origin_url="$(git -C "$checkout" remote get-url origin 2>/dev/null || true)"
    current_sha="$(git -C "$checkout" rev-parse HEAD 2>/dev/null || true)"
    if [[ "$origin_url" != "$plugin_url" ]]; then
        doctor_fail "$plugin_name has unexpected origin: ${origin_url:-none}"
    elif [[ "$current_sha" != "$plugin_sha" ]]; then
        doctor_warn "$plugin_name is at ${current_sha:-unknown}, expected ${plugin_sha:0:12}"
    else
        doctor_ok "$plugin_name is at the pinned commit"
    fi
done <"$ROOT/locks/zsh-plugins.lock"

if [[ -f "$plugin_manifest" ]]; then
    doctor_ok "Plugin ownership manifest exists"
fi

font_dir="$DATA_DIR/fonts"
if [[ "$OSTYPE" == "darwin"* ]]; then
    font_dir="$HOME/Library/Fonts"
fi
if find "$font_dir" -maxdepth 1 -iname '*JetBrainsMono*Nerd*' 2>/dev/null | grep -q .; then
    doctor_ok "JetBrainsMono Nerd Font is installed"
else
    doctor_warn "JetBrainsMono Nerd Font was not found"
fi

printf "\n%bSummary:%b %d OK, %d warnings, %d errors\n\n" "$BOLD" "$NC" "$doctor_ok_count" "$doctor_warning_count" "$doctor_error_count"
if [[ $doctor_error_count -gt 0 ]]; then
    exit 1
fi
