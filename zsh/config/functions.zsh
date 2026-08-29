# ==============================================================================
# Utility Functions
# ==============================================================================

# Create a new directory and change into it
mkcd() {
    if [[ -z "$1" ]]; then
        echo "Usage: mkcd <directory_path>" >&2
        return 1
    fi
    mkdir -p "$1" && cd "$1"
}

# Universal archive extractor
extract() {
    if [[ -z "$1" ]]; then
        echo "Usage: extract <archive_file>" >&2
        return 1
    fi

    if [[ ! -f "$1" ]]; then
        echo "Error: '$1' is not a valid file." >&2
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
        *)           echo "Error: Unable to extract '$1' (unsupported archive format)." >&2; return 1 ;;
    esac
}

# Find process listening on a specific port
port() {
    if [[ -z "$1" ]]; then
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
        echo "Error: Neither 'lsof', 'ss', nor 'netstat' found." >&2
        return 1
    fi
}

# Show local and public IP addresses
myip() {
    printf "Local IP:  "
    if command -v ip >/dev/null 2>&1; then
        ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}' || echo "Unavailable"
    elif command -v ifconfig >/dev/null 2>&1; then
        ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n1 || echo "Unavailable"
    else
        echo "Unavailable"
    fi

    printf "Public IP: "
    if command -v curl >/dev/null 2>&1; then
        curl -fsS --max-time 3 https://icanhazip.com 2>/dev/null || echo "Unavailable"
    else
        echo "Unavailable (curl required)"
    fi
}

# Delete merged local git branches
git-clean-branches() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Error: Not inside a Git repository." >&2
        return 1
    fi

    local main_branch
    main_branch="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")"
    [[ -z "$main_branch" ]] && main_branch="main"

    local branches_to_delete
    branches_to_delete="$(git branch --merged "$main_branch" 2>/dev/null | grep -vE "^\*|\b(main|master|develop)\b" | sed 's/^[[:space:]]*//' || true)"

    if [[ -z "$branches_to_delete" ]]; then
        echo "No merged local branches to delete."
        return 0
    fi

    echo "Merged branches to delete:"
    echo "$branches_to_delete"
    echo ""
    read -r "response?Delete these branches? [y/N]: "
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "$branches_to_delete" | xargs git branch -d
        echo "Merged branches deleted."
    else
        echo "Cancelled."
    fi
}
