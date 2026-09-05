mkcd() {
    if [[ -z "${1:-}" ]]; then
        echo "Usage: mkcd <directory>" >&2
        return 1
    fi
    mkdir -p "$1" && cd "$1"
}

# True if an archive member would escape the current directory.
_archive_member_unsafe() {
    local p="$1"

    [[ "$p" == *$'\n'* || "$p" == *$'\r'* ]] && return 0
    while [[ "$p" == ./* ]]; do
        p="${p#./}"
    done
    p="${p%/}"
    [[ -z "$p" || "$p" == /* || "$p" == ~* ]] && return 0

    local rest="$p" part
    while [[ -n "$rest" ]]; do
        if [[ "$rest" == */* ]]; then
            part="${rest%%/*}"
            rest="${rest#*/}"
        else
            part="$rest"
            rest=""
        fi
        if [[ -z "$part" || "$part" == "." || "$part" == ".." ]]; then
            return 0
        fi
    done
    return 1
}

_reject_unsafe_archive_members() {
    local member
    while IFS= read -r member; do
        [[ -z "$member" ]] && continue
        if _archive_member_unsafe "$member"; then
                echo "Error: refusing to extract unsafe path '$member'" >&2
            return 1
        fi
    done
}

_list_zip_members() {
    if command -v zipinfo >/dev/null 2>&1; then
        zipinfo -1 "$1"
    elif unzip -Z1 "$1" >/dev/null 2>&1; then
        unzip -Z1 "$1"
    else
        unzip -l "$1" | awk 'NR > 3 && $0 !~ /^[- ]+$/ && NF >= 4 { $1=$2=$3=""; sub(/^ +/, ""); print }'
    fi
}

extract() {
    if [[ -z "${1:-}" ]]; then
        echo "Usage: extract <archive>" >&2
        return 1
    fi

    if [[ ! -f "$1" ]]; then
        echo "Error: '$1' is not a regular file" >&2
        return 1
    fi

    case "$1" in
        *.tar.bz2|*.tbz2)
            tar tjf "$1" | _reject_unsafe_archive_members || return 1
            tar xjf "$1"
            ;;
        *.tar.gz|*.tgz)
            tar tzf "$1" | _reject_unsafe_archive_members || return 1
            tar xzf "$1"
            ;;
        *.tar.xz)
            tar tJf "$1" | _reject_unsafe_archive_members || return 1
            tar xJf "$1"
            ;;
        *.tar.zst)
            tar --zstd -tf "$1" | _reject_unsafe_archive_members || return 1
            tar --zstd -xf "$1"
            ;;
        *.tar)
            tar tf "$1" | _reject_unsafe_archive_members || return 1
            tar xf "$1"
            ;;
        *.zip)
            _list_zip_members "$1" | _reject_unsafe_archive_members || return 1
            unzip "$1"
            ;;
        *.bz2) bunzip2 "$1" ;;
        *.gz)  gunzip "$1" ;;
        *.Z)   uncompress "$1" ;;
        *.rar) unrar x "$1" ;;
        *.7z)  7z x "$1" ;;
        *)
            echo "Error: unsupported archive format: $1" >&2
            return 1
            ;;
    esac
}

port() {
    if [[ -z "${1:-}" ]]; then
        echo "Usage: port <number>" >&2
        return 1
    fi

    if command -v lsof >/dev/null 2>&1; then
        lsof -i :"$1"
    elif command -v ss >/dev/null 2>&1; then
        ss -tulpn | grep ":$1\b"
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tulpn | grep ":$1\b"
    else
        echo "Error: lsof, ss, or netstat is required" >&2
        return 1
    fi
}

# `ip route get` field order is not stable; take the token after src.
_local_ip_from_route() {
    awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }'
}

myip() {
    local local_ip="Unavailable"
    local public_ip="Unavailable"

    if command -v ip >/dev/null 2>&1; then
        local_ip="$(ip route get 1.1.1.1 2>/dev/null | _local_ip_from_route)"
    elif command -v ifconfig >/dev/null 2>&1; then
        local_ip="$(ifconfig 2>/dev/null | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n1)"
    fi

    if command -v curl >/dev/null 2>&1; then
        public_ip="$(curl -fsS --max-time 3 https://icanhazip.com 2>/dev/null || echo "Unavailable")"
    fi

    printf "Local IP:  %s\n" "${local_ip:-Unavailable}"
    printf "Public IP: %s\n" "${public_ip:-Unavailable}"
}

git-clean-branches() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Error: not inside a Git repository" >&2
        return 1
    fi

    local main_branch
    main_branch="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')"
    [[ -z "$main_branch" ]] && main_branch="main"

    local branches_to_delete
    branches_to_delete="$(git branch --merged "$main_branch" 2>/dev/null | grep -vE "^\*|\b(main|master|develop)\b" | sed 's/^[[:space:]]*//' || true)"

    if [[ -z "$branches_to_delete" ]]; then
        echo "No merged local branches to delete."
        return 0
    fi

    echo "Merged into '$main_branch':"
    echo "$branches_to_delete"
    echo ""
    read -r "response?Delete these branches? [y/N]: "
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "$branches_to_delete" | xargs git branch -d
        echo "Branches deleted."
    else
        echo "Cancelled."
    fi
}

# Rejects '..' and extra path components; result stays under ~/.ssh/keys/<category>/.
_ssh_safe_key_path() {
    local category="$1"
    local raw_name="$2"

    if [[ -z "$raw_name" || "$raw_name" == "." || "$raw_name" == ".." || "$raw_name" == *[\\/]* ]]; then
        echo "Error: key name must be a single path component: $raw_name" >&2
        return 1
    fi

    local name
    name="$(basename -- "$raw_name")"

    if [[ -z "$name" || "$name" == "." || "$name" == ".." || "$name" == *[\\/]* ]]; then
        echo "Error: invalid key name: $raw_name" >&2
        return 1
    fi

    local dest_dir="$HOME/.ssh/keys/$category"
    mkdir -p "$dest_dir" || return 1
    chmod 700 "$HOME/.ssh" "$HOME/.ssh/keys" "$dest_dir"

    local keys_root dest_dir_real dest_file
    keys_root="$(cd "$HOME/.ssh/keys" && pwd -P)" || return 1
    dest_dir_real="$(cd "$dest_dir" && pwd -P)" || return 1

    case "$dest_dir_real" in
        "$keys_root"/*) ;;
        *)
            echo "Error: refusing to write outside ~/.ssh/keys: $dest_dir_real" >&2
            return 1
            ;;
    esac

    dest_file="$dest_dir_real/$name"
    if [[ "$(dirname -- "$dest_file")" != "$dest_dir_real" ]]; then
        echo "Error: invalid destination path" >&2
        return 1
    fi

    printf '%s\n' "$dest_file"
}

pubkey() {
    local target="${1:-personal}"
    local key_path=""

    if [[ -f "$target" ]]; then
        if [[ "$target" == *.pub ]]; then
            key_path="$target"
        elif [[ -f "${target}.pub" ]]; then
            key_path="${target}.pub"
        else
            echo "Error: '$target' is not a public key" >&2
            return 1
        fi
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
        echo "Error: no public key found for '${target}'. Generate one with: ssh-new ${target}" >&2
        return 1
    fi

    local key_content=""
    key_content="$(grep -vE '^[[:space:]]*(#|$)' "$key_path" | head -n 1 | tr -d '\r\n')"

    if [[ -z "$key_content" ]]; then
        echo "Error: key file is empty or invalid: $key_path" >&2
        return 1
    fi

    if [[ "$key_content" == *"PRIVATE KEY"* ]]; then
        echo "Error: refusing to copy a private key: $key_path" >&2
        return 1
    fi

    case "$key_content" in
        ssh-*|ecdsa-*|sk-*) ;;
        *)
            echo "Error: not an OpenSSH public key: $key_path" >&2
            return 1
            ;;
    esac

    local copied=0
    local method=""

    if command -v wl-copy >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY:-}" || -n "${DISPLAY:-}" ]]; then
        if printf '%s' "$key_content" | wl-copy 2>/dev/null; then
            copied=1
            method="wl-copy"
        fi
    fi

    if [[ $copied -eq 0 ]] && command -v xclip >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
        if printf '%s' "$key_content" | xclip -selection clipboard 2>/dev/null; then
            copied=1
            method="xclip"
        fi
    fi

    if [[ $copied -eq 0 ]] && command -v xsel >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
        if printf '%s' "$key_content" | xsel --clipboard --input 2>/dev/null; then
            copied=1
            method="xsel"
        fi
    fi

    if [[ $copied -eq 0 ]] && command -v pbcopy >/dev/null 2>&1; then
        if printf '%s' "$key_content" | pbcopy 2>/dev/null; then
            copied=1
            method="pbcopy"
        fi
    fi

    local b64_key
    b64_key="$(printf '%s' "$key_content" | base64 | tr -d '\r\n')"
    if [[ -n "${TMUX:-}" ]]; then
        printf '\ePtmux;\e\e]52;c;%s\a\e\\' "$b64_key" >/dev/tty 2>/dev/null || true
    else
        printf '\e]52;c;%s\a' "$b64_key" >/dev/tty 2>/dev/null || true
    fi

    if [[ $copied -eq 0 ]]; then
        method="OSC 52"
    fi

    if [[ -t 1 ]]; then
        echo "Copied with ${method} from $key_path"
        echo "$key_content"
    else
        printf '%s\n' "$key_content"
    fi
}

ssh-new() {
    local category="${1:-}"
    local email="${2:-}"
    local key_name="${3:-id_ed25519}"

    if [[ -z "$category" ]]; then
        echo "Select key category:"
        echo "  1) personal"
        echo "  2) work"
        echo "  3) servers"
        read -r "choice?Choice [1-3]: "
        case "$choice" in
            2) category="work" ;;
            3) category="servers" ;;
            *) category="personal" ;;
        esac
    fi

    if [[ "$category" != "personal" && "$category" != "work" && "$category" != "servers" ]]; then
        echo "Error: category must be personal, work, or servers" >&2
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

    local target_file
    target_file="$(_ssh_safe_key_path "$category" "$key_name")" || return 1

    if [[ -f "$target_file" ]]; then
        echo "Error: key already exists: $target_file" >&2
        return 1
    fi

    echo "Generating key at $target_file"
    ssh-keygen -t ed25519 -C "${email:-$USER}" -f "$target_file"

    chmod 600 "$target_file"
    chmod 644 "${target_file}.pub"

    echo "Created $target_file"
    pubkey "${target_file}.pub"
}

ssh-import() {
    local source_file="${1:-}"
    local category="${2:-servers}"
    local new_name="${3:-}"

    if [[ -z "$source_file" ]]; then
        echo "Usage: ssh-import <key> [personal|work|servers] [name]" >&2
        return 1
    fi

    if [[ ! -f "$source_file" ]]; then
        echo "Error: file not found: $source_file" >&2
        return 1
    fi

    if [[ "$category" != "personal" && "$category" != "work" && "$category" != "servers" ]]; then
        echo "Error: category must be personal, work, or servers" >&2
        return 1
    fi

    local base_name
    base_name="$(basename -- "$source_file")"
    [[ -z "$new_name" ]] && new_name="$base_name"

    local dest_file
    dest_file="$(_ssh_safe_key_path "$category" "$new_name")" || return 1
    new_name="$(basename -- "$dest_file")"

    if [[ -f "$dest_file" ]]; then
        echo "Warning: $dest_file already exists"
        read -r "overwrite?Overwrite? [y/N]: "
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            echo "Cancelled."
            return 0
        fi
    fi

    cp "$source_file" "$dest_file"
    chmod 600 "$dest_file"

    local companion_pub=""
    local source_dir
    source_dir="$(dirname -- "$source_file")"
    local source_no_ext="${base_name%.*}"

    if [[ -f "${source_file}.pub" ]]; then
        companion_pub="${source_file}.pub"
    elif [[ -f "${source_dir}/${source_no_ext}.pub" ]]; then
        companion_pub="${source_dir}/${source_no_ext}.pub"
    fi

    if [[ -n "$companion_pub" ]]; then
        local dest_pub
        dest_pub="$(_ssh_safe_key_path "$category" "${new_name%.*}.pub")" || return 1
        [[ "$dest_pub" == "$dest_file" ]] && dest_pub="${dest_file}.pub"
        cp "$companion_pub" "$dest_pub"
        chmod 644 "$dest_pub"
        echo "Imported public key $dest_pub"
    else
        if ssh-keygen -y -f "$dest_file" > "${dest_file}.pub" 2>/dev/null; then
            chmod 644 "${dest_file}.pub"
            echo "Wrote public key ${dest_file}.pub"
        fi
    fi

    local host_alias="${new_name%.*}"
    echo "Imported $dest_file"
    echo "Suggested host block:"
    echo "Host ${host_alias}"
    echo "    HostName <host>"
    echo "    User <user>"
    echo "    IdentityFile ~/.ssh/keys/${category}/${new_name}"
}
