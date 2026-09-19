# A Mise shim exists before the tool does, so run it rather than only look
# it up: a dangling shim must not error on every shell start.
if command -v zoxide >/dev/null 2>&1; then
    zoxide_init="$(zoxide init zsh 2>/dev/null)" && eval "$zoxide_init"
    unset zoxide_init
fi
