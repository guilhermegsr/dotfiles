# A Mise shim exists before the tool is installed, so run it rather than only
# looking it up: a dangling shim must not print an error on every shell start.
if command -v zoxide >/dev/null 2>&1; then
    zoxide_init="$(zoxide init zsh 2>/dev/null)" && eval "$zoxide_init"
    unset zoxide_init
fi
