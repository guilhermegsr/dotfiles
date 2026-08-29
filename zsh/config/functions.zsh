# Mkdir and cd into directory in one step
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

# Identify process listening on a given port
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
        echo "Error: 'lsof', 'ss', or 'netstat' required to inspect listening ports." >&2
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

# Interactively remove merged local Git branches against upstream default branch
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
