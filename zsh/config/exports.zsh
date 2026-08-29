# XDG Base Directory Specification
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Clean $HOME from tool clutter (XDG compliance)
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
export LESSHISTFILE="$XDG_STATE_HOME/less/history"
export NODE_REPL_HISTORY="$XDG_STATE_HOME/node_repl_history"
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
export DOCKER_CONFIG="$XDG_CONFIG_HOME/docker"

# PATH
export PATH="$HOME/.local/bin:$CARGO_HOME/bin:$PATH"

# Default Editor & Visual (with fallback)
if command -v cursor >/dev/null 2>&1; then
    export EDITOR="cursor"
elif command -v code >/dev/null 2>&1; then
    export EDITOR="code"
elif command -v nvim >/dev/null 2>&1; then
    export EDITOR="nvim"
elif command -v vim >/dev/null 2>&1; then
    export EDITOR="vim"
elif command -v nano >/dev/null 2>&1; then
    export EDITOR="nano"
else
    export EDITOR="vi"
fi
export VISUAL="$EDITOR"

# Default Browser (with fallback)
if command -v firefox >/dev/null 2>&1; then
    export BROWSER="firefox"
elif command -v google-chrome >/dev/null 2>&1; then
    export BROWSER="google-chrome"
elif command -v xdg-open >/dev/null 2>&1; then
    export BROWSER="xdg-open"
fi

# Default Terminal (with fallback)
if command -v konsole >/dev/null 2>&1; then
    export TERMINAL="konsole"
elif command -v ghostty >/dev/null 2>&1; then
    export TERMINAL="ghostty"
elif command -v alacritty >/dev/null 2>&1; then
    export TERMINAL="alacritty"
elif command -v kitty >/dev/null 2>&1; then
    export TERMINAL="kitty"
fi