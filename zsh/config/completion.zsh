autoload -Uz compinit

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
ZCOMPDUMP="$CACHE_DIR/zcompdump-${ZSH_VERSION}"

[[ -d "$CACHE_DIR" ]] || mkdir -p "$CACHE_DIR"

setopt COMPLETE_IN_WORD
setopt ALWAYS_TO_END
setopt AUTO_MENU
setopt AUTO_LIST
setopt PATH_DIRS

# Case-insensitive and substring matching
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# Interactive menu selection and formatting
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' verbose yes
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*:messages' format '%F{purple}-- %d --%f'
zstyle ':completion:*:warnings' format '%F{red}-- No matches found --%f'
zstyle ':completion:*' group-name ''

# Cache completion results
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$CACHE_DIR/zcompcache"

# Process list styling for kill
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

# Regenerate zcompdump at most once a day
if [[ -n "$ZCOMPDUMP"(#qN.m+1) ]]; then
    compinit -d "$ZCOMPDUMP"
    touch "$ZCOMPDUMP"
else
    compinit -C -d "$ZCOMPDUMP"
fi

# Compile dump to bytecode for startup performance
if [[ -s "$ZCOMPDUMP" && (! -s "${ZCOMPDUMP}.zwc" || "$ZCOMPDUMP" -nt "${ZCOMPDUMP}.zwc") ]]; then
    zcompile "$ZCOMPDUMP" 2>/dev/null || true
fi
