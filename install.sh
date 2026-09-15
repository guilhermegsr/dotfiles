#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$DOTFILES_DIR/scripts/lib.sh"
# shellcheck source=scripts/lock-utils.sh
source "$DOTFILES_DIR/scripts/lock-utils.sh"
# shellcheck source=scripts/install/configs.sh
source "$DOTFILES_DIR/scripts/install/configs.sh"
# shellcheck source=scripts/install/plugins.sh
source "$DOTFILES_DIR/scripts/install/plugins.sh"
# shellcheck source=scripts/install/fonts.sh
source "$DOTFILES_DIR/scripts/install/fonts.sh"
# shellcheck source=scripts/install/mise.sh
source "$DOTFILES_DIR/scripts/install/mise.sh"
# shellcheck source=scripts/install/shell.sh
source "$DOTFILES_DIR/scripts/install/shell.sh"
# shellcheck source=scripts/install/onboarding.sh
source "$DOTFILES_DIR/scripts/install/onboarding.sh"

OFFLINE=false
SKIP_CHSH=false
if [[ "${DOTFILES_SKIP_CHSH:-0}" == 1 ]]; then
    SKIP_CHSH=true
fi

usage() {
    cat <<'EOF'
Usage: ./install.sh [--offline] [--no-chsh]

Options:
  --offline  Deploy configuration without downloading plugins, fonts, Mise, or tools
  --no-chsh  Do not change the login shell
  -h, --help Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --offline)
            OFFLINE=true
            ;;
        --no-chsh)
            SKIP_CHSH=true
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            usage >&2
            exit 2
            ;;
    esac
    shift
done

if [[ "$OFFLINE" == false ]]; then
    load_bootstrap_lock "$DOTFILES_DIR/locks/bootstrap.lock"
fi

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_DIR="$(dotfiles_state_dir)"

printf "\n%b=== Install ===%b\n" "${BOLD}${BLUE}" "$NC"
printf "%bSource: %s%b\n" "$DIM" "$DOTFILES_DIR" "$NC"
if [[ "$OFFLINE" == true ]]; then
    info "Offline mode: network-dependent provisioning will be skipped"
fi

install_configs
install_ssh_config
install_plugins
install_fonts
install_mise
configure_login_shell
report_terminal
offer_backup_restore
configure_git_identity
configure_ssh_key
print_install_summary
