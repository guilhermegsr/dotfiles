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

_git_repo_path() {
    local root prefix
    root="$(git rev-parse --show-toplevel 2>/dev/null)" || return
    prefix="$(git rev-parse --show-prefix 2>/dev/null)"
    prefix="${prefix%/}"
    if [[ -n "$prefix" ]]; then
        print -n "${root:t}/$prefix"
    else
        print -n "${root:t}"
    fi
}

_is_git_repo() {
    git rev-parse --is-inside-work-tree &>/dev/null
}

_prompt_path() {
    if _is_git_repo; then
        _git_repo_path
    else
        print -n "%2~"
    fi
}

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