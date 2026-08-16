#!/usr/bin/env zsh

set -e

DOTFILES_DIR="${0:A:h}"

ZSH_CONFIG="$HOME/.config/zsh"
ZSHENV="$HOME/.zshenv"
ZSH_PATH="$(command -v zsh 2>/dev/null || true)"

echo "Uninstalling dotfiles..."

# Remove Zsh configuration
if [[ -L "$ZSH_CONFIG" ]]; then
    TARGET="$(readlink "$ZSH_CONFIG")"

    if [[ "$TARGET" == "$DOTFILES_DIR/zsh" ]]; then
        rm "$ZSH_CONFIG"
        echo "Removed $ZSH_CONFIG"
    else
        echo "Skipping $ZSH_CONFIG: symlink points somewhere else."
    fi
elif [[ -e "$ZSH_CONFIG" ]]; then
    echo "Skipping $ZSH_CONFIG: it is not a symlink."
fi

if [[ -f "$ZSHENV" && -f "$DOTFILES_DIR/zsh/.zshenv" ]]; then
    if cmp -s "$ZSHENV" "$DOTFILES_DIR/zsh/.zshenv"; then
        rm "$ZSHENV"
        echo "Removed $ZSHENV"
    else
        echo "Skipping $ZSHENV: file was modified."
    fi
fi

BASH_PATH="$(command -v bash 2>/dev/null || true)"

if [[ -n "$BASH_PATH" && -n "$ZSH_PATH" ]]; then
    CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7)"

    if [[ "$CURRENT_SHELL" == "$ZSH_PATH" ]]; then
        echo "Changing default shell back to $BASH_PATH..."
        chsh -s "$BASH_PATH"
    fi
fi

echo "Dotfiles uninstalled successfully."