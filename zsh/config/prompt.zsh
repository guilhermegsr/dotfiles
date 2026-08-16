# ~/.config/zsh/config/prompt.zsh

autoload -Uz vcs_info
autoload -Uz colors && colors

setopt PROMPT_SUBST

# Git

zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats ' %F{242}on%f %F{magenta}󰘬 %b%f'
zstyle ':vcs_info:git:*' actionformats ' %F{242}on%f %F{magenta}󰘬 %b%f %F{yellow}(%a)%f'

_git_status() {
    local git_status
    local line
    local staged=0
    local unstaged=0
    local untracked=0

    git_status="$(git status --porcelain 2>/dev/null)"

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        if [[ "$line" == '??'* ]]; then
            ((untracked++))
            continue
        fi

        if [[ "${line[1]}" != ' ' ]]; then
            ((staged++))
        fi

        if [[ "${line[2]}" != ' ' ]]; then
            ((unstaged++))
        fi
    done <<< "$git_status"

    (( staged > 0 || unstaged > 0 || untracked > 0 )) || return

    print -n " ["
    (( staged > 0 )) && print -n "%F{green}+${staged}%f "
    (( unstaged > 0 )) && print -n "%F{yellow}*${unstaged}%f "
    (( untracked > 0 )) && print -n "%F{red}?${untracked}%f"
    print -n "]"
}

_git_repo_name() {
    local root

    root="$(git rev-parse --show-toplevel 2>/dev/null)" || return
    print -n "${root:t}"
}

_is_git_repo() {
    git rev-parse --is-inside-work-tree &>/dev/null
}

# Path

_prompt_path() {
    if _is_git_repo; then
        _git_repo_name
    else
        print -n "%2~"
    fi
}

# Prompt

_prompt_update() {
    vcs_info
    PROMPT_PATH="$(_prompt_path)"
    PROMPT_GIT_STATUS="$(_git_status)"
}

precmd() {
    print ""
    _prompt_update
}

PROMPT='%F{242}in%f %F{cyan}${PROMPT_PATH}%f${vcs_info_msg_0_}${PROMPT_GIT_STATUS}
 %(?:%F{green}󱞩%f:%F{red}󱞩%f) '