ZSH_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"

source "$ZSH_CONFIG_HOME/config/exports.zsh"
source "$ZSH_CONFIG_HOME/integrations/mise.zsh"

source "$ZSH_CONFIG_HOME/config/history.zsh"
source "$ZSH_CONFIG_HOME/config/completion.zsh"
source "$ZSH_CONFIG_HOME/config/keybindings.zsh"
source "$ZSH_CONFIG_HOME/config/aliases.zsh"
source "$ZSH_CONFIG_HOME/config/functions.zsh"

source "$ZSH_CONFIG_HOME/integrations/fzf.zsh"
source "$ZSH_CONFIG_HOME/integrations/zoxide.zsh"

source "$ZSH_CONFIG_HOME/config/prompt.zsh"

[[ -f "$ZSH_CONFIG_HOME/local.zsh" ]] && source "$ZSH_CONFIG_HOME/local.zsh"

# syntax-highlighting must load last
source "$ZSH_CONFIG_HOME/integrations/plugins.zsh"