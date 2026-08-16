#!/usr/bin/env zsh

set -e

DOTFILES_DIR="${0:A:h}"

echo "Installing dotfiles..."

# zsh configuration
mkdir -p "$HOME/.config"

if [[ -e "$HOME/.config/zsh" && ! -L "$HOME/.config/zsh" ]]; then
    echo "Error: $HOME/.config/zsh already exists and is not a symlink."
    echo "Please move or remove it before continuing."
    exit 1
fi

ln -sfn "$DOTFILES_DIR/zsh" "$HOME/.config/zsh"

cp "$DOTFILES_DIR/zsh/.zshenv" "$HOME/.zshenv"

ZSH_PATH="$(command -v zsh)"

if [[ -z "$ZSH_PATH" ]]; then
    echo "Error: zsh is not installed."
    exit 1
fi

if [[ "$SHELL" != "$ZSH_PATH" ]]; then
    echo "Changing default shell to $ZSH_PATH..."
    chsh -s "$ZSH_PATH"
fi

echo "Zsh configuration installed successfully."
echo "Default shell: $ZSH_PATH"