ZSH_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"

# Environment & Runtimes
source "$ZSH_CONFIG_HOME/config/exports.zsh"
source "$ZSH_CONFIG_HOME/integrations/mise.zsh"

# Configuration
source "$ZSH_CONFIG_HOME/config/history.zsh"
source "$ZSH_CONFIG_HOME/config/completion.zsh"
source "$ZSH_CONFIG_HOME/config/keybindings.zsh"
source "$ZSH_CONFIG_HOME/config/aliases.zsh"

# Integrations
source "$ZSH_CONFIG_HOME/integrations/fzf.zsh"
source "$ZSH_CONFIG_HOME/integrations/zoxide.zsh"

# Prompt
source "$ZSH_CONFIG_HOME/config/prompt.zsh"

# Plugins (autosuggestions & syntax highlighting)
source "$ZSH_CONFIG_HOME/integrations/plugins.zsh"

# Local & Private Configuration (untracked)
[[ -f "$ZSH_CONFIG_HOME/local.zsh" ]] && source "$ZSH_CONFIG_HOME/local.zsh"