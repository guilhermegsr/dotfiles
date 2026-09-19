if [[ -z "${STARSHIP_CONFIG:-}" ]]; then
    export STARSHIP_CONFIG="${${(%):-%N}:A:h:h:h}/starship/starship.toml"
fi

if command -v starship >/dev/null 2>&1; then
    starship_init="$(starship init zsh 2>/dev/null)" && eval "$starship_init"
    unset starship_init
fi
