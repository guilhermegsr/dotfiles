zmodload zsh/datetime
autoload -Uz vcs_info
autoload -Uz colors && colors

setopt PROMPT_SUBST

# VCS info styling
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats ' %F{242}on%f %F{magenta}󰘬 %b%f'
zstyle ':vcs_info:git:*' actionformats ' %F{242}on%f %F{magenta}󰘬 %b%f %F{yellow}(%a)%f'

# Command execution timer
typeset -g _cmd_start_time=0
typeset -g PROMPT_CMD_DURATION=""

preexec() {
    _cmd_start_time=$EPOCHREALTIME
}

_cmd_duration() {
    if (( _cmd_start_time > 0 )); then
        local -F elapsed=$(( EPOCHREALTIME - _cmd_start_time ))
        _cmd_start_time=0
        if (( elapsed >= 2.0 )); then
            if (( elapsed >= 60.0 )); then
                local -i mins=$(( elapsed / 60 ))
                local -i secs=$(( elapsed - mins * 60 ))
                print -n "%F{yellow}󱎫 ${mins}m ${secs}s%f"
            else
                printf "%%F{yellow}󱎫 %.1fs%%f" "$elapsed"
            fi
            return
        fi
    fi
}

_git_divergence() {
    local counts
    counts="$(git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)" || return
    local ahead="${counts%%	*}"
    local behind="${counts#*	}"
    local -a parts=()
    (( ahead > 0 )) && parts+=("%F{cyan}⇡${ahead}%f")
    (( behind > 0 )) && parts+=("%F{magenta}⇣${behind}%f")
    (( ${#parts} > 0 )) || return
    print -n " ${(j: :)parts}"
}

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
    (( untracked > 0 )) && indicators+=("%F{blue}?${untracked}%f")

    (( ${#indicators} > 0 )) || return

    print -n " [${(j: :)indicators}]"
}

_prompt_update() {
    vcs_info
    PROMPT_CMD_DURATION="$(_cmd_duration)"

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
        PROMPT_GIT_DIVERGENCE="$(_git_divergence)"
        PROMPT_GIT_STATUS="$(_git_status)"
    else
        PROMPT_PATH="%2~"
        PROMPT_GIT_DIVERGENCE=""
        PROMPT_GIT_STATUS=""
    fi
}

precmd() {
    print ""
    _prompt_update
}

# Two-line minimal prompt with right prompt for command duration
PROMPT='%F{242}in%f %F{cyan}${PROMPT_PATH}%f${vcs_info_msg_0_}${PROMPT_GIT_DIVERGENCE}${PROMPT_GIT_STATUS}
 %(?:%F{green}󱞩%f:%F{red}󱞩 [%?]%f) '

RPROMPT='${PROMPT_CMD_DURATION}'