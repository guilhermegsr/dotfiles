autoload -Uz vcs_info
autoload -Uz colors && colors

setopt PROMPT_SUBST

zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats ' %F{242}on%f %F{magenta}󰘬 %b%f'
zstyle ':vcs_info:git:*' actionformats ' %F{242}on%f %F{magenta}󰘬 %b%f %F{yellow}(%a)%f'

_git_status() {
    local git_status line
    local staged=0 unstaged=0 untracked=0
    local -a indicators=()

    git_status="$(git status --porcelain 2>/dev/null)" || return

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        if [[ "$line" == '??'* ]]; then
            ((untracked++))
            continue
        fi

        [[ "${line[1]}" != ' ' ]] && ((staged++))
        [[ "${line[2]}" != ' ' ]] && ((unstaged++))
    done <<< "$git_status"

    (( staged > 0 )) && indicators+=("%F{green}+${staged}%f")
    (( unstaged > 0 )) && indicators+=("%F{yellow}*${unstaged}%f")
    (( untracked > 0 )) && indicators+=("%F{red}?${untracked}%f")

    (( ${#indicators} > 0 )) || return

    print -n " [${(j: :)indicators}]"
}

_prompt_update() {
    vcs_info
    local git_info
    if git_info="$(git rev-parse --show-toplevel --show-prefix 2>/dev/null)"; then
        local -a lines=("${(f)git_info}")
        local repo_root="${lines[1]}"
        local repo_prefix="${lines[2]%/}"
        if [[ -n "$repo_prefix" ]]; then
            PROMPT_PATH="${repo_root:t}/$repo_prefix"
        else
            PROMPT_PATH="${repo_root:t}"
        fi
        PROMPT_GIT_STATUS="$(_git_status)"
    else
        PROMPT_PATH="%2~"
        PROMPT_GIT_STATUS=""
    fi
}

precmd() {
    print ""
    _prompt_update
}

PROMPT='%F{242}in%f %F{cyan}${PROMPT_PATH}%f${vcs_info_msg_0_}${PROMPT_GIT_STATUS}
 %(?:%F{green}󱞩%f:%F{red}󱞩%f) '