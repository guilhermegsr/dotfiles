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

alias grep='grep --color=auto'

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

alias df='df -h'
alias free='free -h'
alias mkdir='mkdir -p'

# SSH
alias ssh-keys='ssh-add -l'
alias ssh-clean='rm -rf ~/.ssh/sockets/*'