# Character encoding & localization
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# XDG Base Directory specification compliance
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Redirect tool state and configs to adhere to XDG layout
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
export LESSHISTFILE="$XDG_STATE_HOME/less/history"
export NODE_REPL_HISTORY="$XDG_STATE_HOME/node_repl_history"
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
export DOCKER_CONFIG="$XDG_CONFIG_HOME/docker"

export PATH="$HOME/.local/bin:$CARGO_HOME/bin:$PATH"

# Editor resolution with CLI prioritization for Git & terminal workflows
if command -v nvim >/dev/null 2>&1; then
    export EDITOR="nvim"
elif command -v vim >/dev/null 2>&1; then
    export EDITOR="vim"
elif command -v cursor >/dev/null 2>&1; then
    export EDITOR="cursor --wait"
elif command -v code >/dev/null 2>&1; then
    export EDITOR="code --wait"
elif command -v nano >/dev/null 2>&1; then
    export EDITOR="nano"
else
    export EDITOR="vi"
fi
export VISUAL="$EDITOR"

# Syntax-highlighted man pages via bat
if command -v bat >/dev/null 2>&1; then
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

# Web browser resolution
if command -v firefox >/dev/null 2>&1; then
    export BROWSER="firefox"
elif command -v brave-origin >/dev/null 2>&1; then
    export BROWSER="brave-origin"
elif command -v brave-browser >/dev/null 2>&1; then
    export BROWSER="brave-browser"
elif command -v brave >/dev/null 2>&1; then
    export BROWSER="brave"
elif command -v xdg-open >/dev/null 2>&1; then
    export BROWSER="xdg-open"
fi

# Terminal emulator resolution (Alacritty prioritized)
if command -v alacritty >/dev/null 2>&1; then
    export TERMINAL="alacritty"
elif command -v ghostty >/dev/null 2>&1; then
    export TERMINAL="ghostty"
elif command -v kitty >/dev/null 2>&1; then
    export TERMINAL="kitty"
elif command -v konsole >/dev/null 2>&1; then
    export TERMINAL="konsole"
fi