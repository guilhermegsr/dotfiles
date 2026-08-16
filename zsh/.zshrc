# ~/.config/zsh/.zshrc

ZSH_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"

source "$ZSH_CONFIG_HOME/config/exports.zsh"
source "$ZSH_CONFIG_HOME/config/history.zsh"
source "$ZSH_CONFIG_HOME/config/aliases.zsh"
source "$ZSH_CONFIG_HOME/integrations/mise.zsh"
source "$ZSH_CONFIG_HOME/config/prompt.zsh"