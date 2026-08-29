# Modern CLI replacements
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons --color=auto -l'
    alias la='eza --icons --color=auto -la'
    alias tree='eza --icons --color=auto --tree'
else
    alias ls='ls -l --color=auto'
    alias la='ls -la --color=auto'
fi

if command -v bat >/dev/null 2>&1; then
    alias cat='bat --paging=never'
    alias batp='bat'
fi

if command -v rg >/dev/null 2>&1; then
    alias grep='rg'
else
    alias grep='grep --color=auto'
fi

if command -v fd >/dev/null 2>&1; then
    alias find='fd'
fi

if command -v zoxide >/dev/null 2>&1; then
    alias cd='z'
fi

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# Safety defaults
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Utilities
alias df='df -h'
alias free='free -h'
alias mkdir='mkdir -p'