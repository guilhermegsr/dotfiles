bindkey -e

autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

bindkey '^[[A' up-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search

bindkey '^[[H' beginning-of-line
bindkey '^[[1~' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[4~' end-of-line
bindkey '^[[3~' delete-char
bindkey '^?' backward-delete-char

bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[^[[C' forward-word
bindkey '^[^[[D' backward-word
bindkey '^[f' forward-word
bindkey '^[b' backward-word

autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line
