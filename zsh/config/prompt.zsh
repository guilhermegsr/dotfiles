zmodload zsh/datetime
autoload -Uz vcs_info
autoload -Uz colors && colors
autoload -Uz add-zsh-hook

setopt PROMPT_SUBST

zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats ' %F{242}on%f %F{magenta}󰘬 %b%f'
zstyle ':vcs_info:git:*' actionformats ' %F{242}on%f %F{magenta}󰘬 %b%f %F{yellow}(%a)%f'

typeset -g _cmd_start_time=0
typeset -g PROMPT_CMD_DURATION=""
typeset -g _prompt_git_cache_key=""
typeset -g _prompt_git_cache_path=""
typeset -g _prompt_git_cache_divergence=""
typeset -g _prompt_git_cache_status=""
typeset -g _prompt_git_cache_vcs=""

_prompt_preexec() {
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

_prompt_index_mtime() {
    local git_dir="$1"
    if stat -c %Y "$git_dir/index" >/dev/null 2>&1; then
        stat -c %Y "$git_dir/index" 2>/dev/null
    else
        stat -f %m "$git_dir/index" 2>/dev/null
    fi
}

# -uno skips untracked (large trees).
_prompt_git_from_status() {
    local header="" line staged=0 unstaged=0
    local ahead=0 behind=0
    local -a indicators=() parts=()

    IFS= read -r header
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == '??'* ]] && continue
        [[ "${line[1]}" != ' ' ]] && ((staged++))
        [[ "${line[2]}" != ' ' ]] && ((unstaged++))
    done

    if [[ "$header" =~ 'ahead ([0-9]+)' ]]; then
        ahead="${match[1]}"
    fi
    if [[ "$header" =~ 'behind ([0-9]+)' ]]; then
        behind="${match[1]}"
    fi
    (( ahead > 0 )) && parts+=("%F{cyan}⇡${ahead}%f")
    (( behind > 0 )) && parts+=("%F{magenta}⇣${behind}%f")
    (( staged > 0 )) && indicators+=("%F{green}+${staged}%f")
    (( unstaged > 0 )) && indicators+=("%F{yellow}*${unstaged}%f")

    if (( ${#parts} > 0 )); then
        PROMPT_GIT_DIVERGENCE=" ${(j: :)parts}"
    else
        PROMPT_GIT_DIVERGENCE=""
    fi
    if (( ${#indicators} > 0 )); then
        PROMPT_GIT_STATUS=" [${(j: :)indicators}]"
    else
        PROMPT_GIT_STATUS=""
    fi
}

_prompt_update() {
    PROMPT_CMD_DURATION="$(_cmd_duration)"

    local git_dir git_info
    if ! git_dir="$(git rev-parse --git-dir 2>/dev/null)"; then
        PROMPT_PATH="%2~"
        PROMPT_GIT_DIVERGENCE=""
        PROMPT_GIT_STATUS=""
        vcs_info_msg_0_=""
        return
    fi

    local head index_mtime cache_key
    head="$(git rev-parse HEAD 2>/dev/null || echo detached)"
    index_mtime="$(_prompt_index_mtime "$git_dir")"
    cache_key="${git_dir}:${head}:${index_mtime}"

    if [[ "$cache_key" == "$_prompt_git_cache_key" ]]; then
        PROMPT_PATH="$_prompt_git_cache_path"
        PROMPT_GIT_DIVERGENCE="$_prompt_git_cache_divergence"
        PROMPT_GIT_STATUS="$_prompt_git_cache_status"
        vcs_info_msg_0_="$_prompt_git_cache_vcs"
        return
    fi

    vcs_info

    if git_info="$(git rev-parse --show-toplevel --show-prefix 2>/dev/null)"; then
        local -a lines=("${(f)git_info}")
        local repo_root="${lines[1]}"
        local repo_prefix="${lines[2]%/}"
        if [[ -n "$repo_prefix" ]]; then
            PROMPT_PATH="${repo_root:t}/$repo_prefix"
        else
            PROMPT_PATH="${repo_root:t}"
        fi
        _prompt_git_from_status < <(git -c color.status=false status --porcelain=v1 -uno -b 2>/dev/null)
    else
        PROMPT_PATH="%2~"
        PROMPT_GIT_DIVERGENCE=""
        PROMPT_GIT_STATUS=""
    fi

    _prompt_git_cache_key="$cache_key"
    _prompt_git_cache_path="$PROMPT_PATH"
    _prompt_git_cache_divergence="$PROMPT_GIT_DIVERGENCE"
    _prompt_git_cache_status="$PROMPT_GIT_STATUS"
    _prompt_git_cache_vcs="${vcs_info_msg_0_}"
}

_prompt_precmd() {
    print ""
    _prompt_update
}

add-zsh-hook precmd _prompt_precmd
add-zsh-hook preexec _prompt_preexec

PROMPT='%F{242}in%f %F{cyan}${PROMPT_PATH}%f${vcs_info_msg_0_}${PROMPT_GIT_DIVERGENCE}${PROMPT_GIT_STATUS}
 %(?:%F{green}󱞩%f:%F{red}󱞩 [%?]%f) '

RPROMPT='${PROMPT_CMD_DURATION}'
