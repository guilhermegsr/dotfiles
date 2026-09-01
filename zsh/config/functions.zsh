# Create target directory hierarchy and change into it
mkcd() {
    if [[ -z "${1:-}" ]]; then
        echo "Usage: mkcd <directory>" >&2
        return 1
    fi
    mkdir -p "$1" && cd "$1"
}

# Universal archive extraction utility
extract() {
    if [[ -z "${1:-}" ]]; then
        echo "Usage: extract <archive_file>" >&2
        return 1
    fi

    if [[ ! -f "$1" ]]; then
        echo "Error: File '$1' not found or is not a regular file." >&2
        return 1
    fi

    case "$1" in
        *.tar.bz2)   tar xjf "$1"        ;;
        *.tar.gz)    tar xzf "$1"        ;;
        *.bz2)       bunzip2 "$1"        ;;
        *.rar)       unrar x "$1"        ;;
        *.gz)        gunzip "$1"         ;;
        *.tar)       tar xf "$1"         ;;
        *.tbz2)      tar xjf "$1"        ;;
        *.tgz)       tar xzf "$1"        ;;
        *.zip)       unzip "$1"          ;;
        *.Z)         uncompress "$1"     ;;
        *.7z)        7z x "$1"           ;;
        *.tar.xz)    tar xJf "$1"        ;;
        *.tar.zst)   tar --zstd -xf "$1" ;;
        *)           echo "Error: Unsupported archive format for '$1'." >&2; return 1 ;;
    esac
}

# Inspect active processes bound to a given network port
port() {
    if [[ -z "${1:-}" ]]; then
        echo "Usage: port <port_number>" >&2
        return 1
    fi

    if command -v lsof >/dev/null 2>&1; then
        lsof -i :"$1"
    elif command -v ss >/dev/null 2>&1; then
        ss -tulpn | grep ":$1\b"
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tulpn | grep ":$1\b"
    else
        echo "Error: 'lsof', 'ss', or 'netstat' is required to inspect listening ports." >&2
        return 1
    fi
}

# Resolve local and public IP addresses
myip() {
    local local_ip="Unavailable"
    local public_ip="Unavailable"

    if command -v ip >/dev/null 2>&1; then
        local_ip="$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')"
    elif command -v ifconfig >/dev/null 2>&1; then
        local_ip="$(ifconfig 2>/dev/null | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n1)"
    fi

    if command -v curl >/dev/null 2>&1; then
        public_ip="$(curl -fsS --max-time 3 https://icanhazip.com 2>/dev/null || echo "Unavailable")"
    fi

    printf "Local IP:  %s\n" "${local_ip:-Unavailable}"
    printf "Public IP: %s\n" "${public_ip:-Unavailable}"
}

# Interactively prune merged local Git branches against upstream default branch
git-clean-branches() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Error: Not inside a Git work tree." >&2
        return 1
    fi

    local main_branch
    main_branch="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')"
    [[ -z "$main_branch" ]] && main_branch="main"

    local branches_to_delete
    branches_to_delete="$(git branch --merged "$main_branch" 2>/dev/null | grep -vE "^\*|\b(main|master|develop)\b" | sed 's/^[[:space:]]*//' || true)"

    if [[ -z "$branches_to_delete" ]]; then
        echo "No merged local branches to prune."
        return 0
    fi

    echo "Local branches merged into '$main_branch':"
    echo "$branches_to_delete"
    echo ""
    read -r "response?Prune these branches? [y/N]: "
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "$branches_to_delete" | xargs git branch -d
        echo "Branches pruned successfully."
    else
        echo "Pruning aborted."
    fi
}

# Copy SSH public key to system clipboard or stdout
pubkey() {
    local target="${1:-personal}"
    local key_path=""

    if [[ -f "$target" ]]; then
        key_path="$target"
    elif [[ -f "${target}.pub" ]]; then
        key_path="${target}.pub"
    elif [[ -f "$HOME/.ssh/keys/${target}/id_ed25519.pub" ]]; then
        key_path="$HOME/.ssh/keys/${target}/id_ed25519.pub"
    elif [[ -f "$HOME/.ssh/keys/${target}/id_rsa.pub" ]]; then
        key_path="$HOME/.ssh/keys/${target}/id_rsa.pub"
    elif [[ -f "$HOME/.ssh/keys/servers/${target}.pub" ]]; then
        key_path="$HOME/.ssh/keys/servers/${target}.pub"
    elif [[ -f "$HOME/.ssh/id_ed25519.pub" ]]; then
        key_path="$HOME/.ssh/id_ed25519.pub"
    elif [[ -f "$HOME/.ssh/id_rsa.pub" ]]; then
        key_path="$HOME/.ssh/id_rsa.pub"
    else
        echo "Error: No public key found for '${target}'." >&2
        echo "Generate one with: ssh-new ${target}" >&2
        return 1
    fi

    local key_content=""
    # Extract the public key as a single sanitized line
    key_content="$(grep -v '^[[:space:]]*$' "$key_path" | head -n 1 | tr -d '\r\n')"

    if [[ -z "$key_content" ]]; then
        echo "Error: Key file '$key_path' is empty or invalid." >&2
        return 1
    fi

    local copied=0
    local method=""

    # 1. Wayland clipboard
    if command -v wl-copy >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY:-}" || -n "${DISPLAY:-}" ]]; then
        if printf '%s' "$key_content" | wl-copy 2>/dev/null; then
            copied=1
            method="wl-copy"
        fi
    fi

    # 2. X11 clipboard (xclip)
    if [[ $copied -eq 0 ]] && command -v xclip >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
        if printf '%s' "$key_content" | xclip -selection clipboard 2>/dev/null; then
            copied=1
            method="xclip"
        fi
    fi

    # 3. X11 clipboard (xsel)
    if [[ $copied -eq 0 ]] && command -v xsel >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
        if printf '%s' "$key_content" | xsel --clipboard --input 2>/dev/null; then
            copied=1
            method="xsel"
        fi
    fi

    # 4. macOS clipboard
    if [[ $copied -eq 0 ]] && command -v pbcopy >/dev/null 2>&1; then
        if printf '%s' "$key_content" | pbcopy 2>/dev/null; then
            copied=1
            method="pbcopy"
        fi
    fi

    # 5. Terminal OSC 52 sequence (works over SSH and in all modern terminals without GUI tools)
    local b64_key
    b64_key="$(printf '%s' "$key_content" | base64 | tr -d '\r\n')"
    if [[ -n "${TMUX:-}" ]]; then
        printf '\ePtmux;\e\e]52;c;%s\a\e\\' "$b64_key" >/dev/tty 2>/dev/null || true
    else
        printf '\e]52;c;%s\a' "$b64_key" >/dev/tty 2>/dev/null || true
    fi

    if [[ $copied -eq 0 ]]; then
        method="OSC 52 (terminal clipboard)"
    fi

    # Output formatting
    if [[ -t 1 ]]; then
        echo "✓ Public key copied to clipboard via ${method}."
        echo "  Source: $key_path"
        echo ""
        echo "$key_content"
    else
        printf '%s\n' "$key_content"
    fi
}

# Generate an ed25519 SSH keypair into the structured keys directory
ssh-new() {
    local category="${1:-}"
    local email="${2:-}"
    local key_name="${3:-id_ed25519}"

    if [[ -z "$category" ]]; then
        echo "Select key category:"
        echo "  1) personal (default)"
        echo "  2) work"
        echo "  3) servers"
        read -r "choice?Choice [1-3] (default: 1): "
        case "$choice" in
            2) category="work" ;;
            3) category="servers" ;;
            *) category="personal" ;;
        esac
    fi

    if [[ "$category" != "personal" && "$category" != "work" && "$category" != "servers" ]]; then
        echo "Error: Invalid category '$category'. Expected: personal, work, or servers." >&2
        return 1
    fi

    if [[ -z "$email" ]]; then
        local default_email
        default_email="$(git config user.email 2>/dev/null || true)"
        if [[ -n "$default_email" ]]; then
            read -r "email?Email / comment [${default_email}]: "
            [[ -z "$email" ]] && email="$default_email"
        else
            read -r "email?Email / comment: "
        fi
    fi

    local target_dir="$HOME/.ssh/keys/$category"
    local target_file="$target_dir/$key_name"

    mkdir -p "$target_dir"
    chmod 700 "$target_dir"

    if [[ -f "$target_file" ]]; then
        echo "Error: Key '$target_file' already exists." >&2
        return 1
    fi

    echo "Generating ed25519 key at '$target_file'..."
    ssh-keygen -t ed25519 -C "${email:-$USER}" -f "$target_file"

    chmod 600 "$target_file"
    chmod 644 "${target_file}.pub"

    echo ""
    echo "Key pair successfully generated at '$target_file'."
    pubkey "$target_file"
}

# Import and secure downloaded SSH keys (e.g. AWS/VPS .pem, .key, and companion .pub)
ssh-import() {
    local source_file="${1:-}"
    local category="${2:-servers}"
    local new_name="${3:-}"

    if [[ -z "$source_file" ]]; then
        echo "Usage: ssh-import <path_to_key_file> [category] [new_name]" >&2
        echo "Example: ssh-import ~/Downloads/my-vps.key servers vps-prod" >&2
        return 1
    fi

    if [[ ! -f "$source_file" ]]; then
        echo "Error: Source key file '$source_file' not found." >&2
        return 1
    fi

    if [[ "$category" != "personal" && "$category" != "work" && "$category" != "servers" ]]; then
        echo "Error: Invalid category '$category'. Expected: personal, work, or servers." >&2
        return 1
    fi

    local base_name
    base_name="$(basename "$source_file")"
    [[ -z "$new_name" ]] && new_name="$base_name"

    local dest_dir="$HOME/.ssh/keys/$category"
    local dest_file="$dest_dir/$new_name"

    mkdir -p "$dest_dir"
    chmod 700 "$dest_dir"

    if [[ -f "$dest_file" ]]; then
        echo "Warning: Destination '$dest_file' already exists."
        read -r "overwrite?Overwrite? [y/N]: "
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            echo "Import aborted."
            return 0
        fi
    fi

    cp "$source_file" "$dest_file"
    chmod 600 "$dest_file"

    local companion_pub=""
    local source_dir
    source_dir="$(dirname "$source_file")"
    local source_no_ext="${base_name%.*}"

    if [[ -f "${source_file}.pub" ]]; then
        companion_pub="${source_file}.pub"
    elif [[ -f "${source_dir}/${source_no_ext}.pub" ]]; then
        companion_pub="${source_dir}/${source_no_ext}.pub"
    fi

    if [[ -n "$companion_pub" ]]; then
        local dest_pub="${dest_dir}/${new_name%.*}.pub"
        [[ "$dest_pub" == "$dest_file" ]] && dest_pub="${dest_file}.pub"
        cp "$companion_pub" "$dest_pub"
        chmod 644 "$dest_pub"
        echo "Imported matching public key: '$dest_pub'"
    else
        if ssh-keygen -y -f "$dest_file" > "${dest_file}.pub" 2>/dev/null; then
            chmod 644 "${dest_file}.pub"
            echo "Extracted public key: '${dest_file}.pub'"
        fi
    fi

    local host_alias="${new_name%.*}"
    echo ""
    echo "Key successfully imported and secured at '$dest_file' (mode 0600)."
    echo ""
    echo "Suggested host block for ~/.ssh/config.local:"
    echo "--------------------------------------------------------"
    echo "Host ${host_alias}"
    echo "    HostName <SERVER_IP_OR_DOMAIN>"
    echo "    User <SSH_USER>"
    echo "    IdentityFile ~/.ssh/keys/${category}/${new_name}"
    echo "--------------------------------------------------------"
}
