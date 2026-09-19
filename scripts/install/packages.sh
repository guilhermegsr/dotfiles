# shellcheck shell=bash
# Only what Mise cannot provide: interpreters and CLI tools come from
# mise/config.toml, which is already OS-agnostic. What is left is small enough
# that a per-manager name list stays honest instead of becoming a translation
# table nobody maintains.

detect_package_manager() {
    if [[ "$OSTYPE" == darwin* ]] && command -v brew >/dev/null 2>&1; then
        printf 'brew'
    elif command -v dnf >/dev/null 2>&1; then
        printf 'dnf'
    elif command -v apt-get >/dev/null 2>&1; then
        printf 'apt'
    elif command -v pacman >/dev/null 2>&1; then
        printf 'pacman'
    else
        return 1
    fi
}

package_is_installed() {
    local manager="$1"
    local package="$2"
    case "$manager" in
        dnf) rpm -q "$package" >/dev/null 2>&1 ;;
        apt) dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q '^install ok installed$' ;;
        pacman) pacman -Qi "$package" >/dev/null 2>&1 ;;
        brew) brew list --versions "$package" >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

read_package_list() {
    local list="$1"
    local line
    PACKAGE_LIST=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="${line//[[:space:]]/}"
        [[ -z "$line" ]] && continue
        PACKAGE_LIST+=("$line")
    done <"$list"
}

install_packages() {
    section "System packages"

    if [[ "$WITH_PACKAGES" != true ]]; then
        info "Skipping system packages; pass --with-packages to install them"
        return 0
    fi
    if [[ "$OFFLINE" == true ]]; then
        info "Offline mode; skipping system packages"
        return 0
    fi

    local manager
    if ! manager="$(detect_package_manager)"; then
        warn "No supported package manager found (dnf, apt, pacman, brew)"
        return 0
    fi

    local list="$DOTFILES_DIR/packages/${manager}.txt"
    if [[ ! -f "$list" ]]; then
        warn "No package list for $manager at $list"
        return 0
    fi

    read_package_list "$list"
    if [[ ${#PACKAGE_LIST[@]} -eq 0 ]]; then
        info "$list declares no packages for this system"
        return 0
    fi

    local missing=() package
    for package in "${PACKAGE_LIST[@]}"; do
        package_is_installed "$manager" "$package" || missing+=("$package")
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        success "Every package in $list is already installed"
        return 0
    fi

    local command=()
    case "$manager" in
        dnf) command=(dnf install -y "${missing[@]}") ;;
        apt) command=(apt-get install -y "${missing[@]}") ;;
        pacman) command=(pacman -S --needed --noconfirm "${missing[@]}") ;;
        brew) command=(brew install "${missing[@]}") ;;
    esac

    if [[ "$manager" != brew && "${EUID:-$(id -u)}" -ne 0 ]]; then
        if ! command -v sudo >/dev/null 2>&1; then
            warn "sudo was not found. Install these yourself: ${missing[*]}"
            return 0
        fi
        command=(sudo "${command[@]}")
    fi

    info "Missing: ${missing[*]}"
    info "Running: ${command[*]}"

    if [[ "$manager" == apt ]]; then
        if [[ "${command[0]}" == sudo ]]; then
            sudo apt-get update || warn "apt-get update failed; trying the install anyway"
        else
            apt-get update || warn "apt-get update failed; trying the install anyway"
        fi
    fi

    if "${command[@]}"; then
        success "Installed ${#missing[@]} package(s)"
    else
        warn "Package installation failed. Run it yourself: ${command[*]}"
    fi
}
