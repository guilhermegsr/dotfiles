if [[ -z "${STARSHIP_CONFIG:-}" ]]; then
    export STARSHIP_CONFIG="${${(%):-%N}:A:h:h:h}/starship/starship.toml"
fi

if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi
