HIST_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/zsh"
HISTFILE="$HIST_DIR/history"

mkdir -p "$HIST_DIR"
[[ -f "$HISTFILE" ]] || : >"$HISTFILE"
chmod 600 "$HISTFILE"

HISTSIZE=50000
SAVEHIST=50000

# Applied when the history file is written; the line stays in the session's
# in-memory history until then.
HISTORY_IGNORE='(*(TOKEN|SECRET|PASSWORD|PASSWD|API_KEY|APIKEY|ACCESS_KEY|PRIVATE_KEY)=*|*--password*|*--token*|*Authorization:*|gh auth login*|ssh-add*|openssl *)'

setopt EXTENDED_HISTORY
setopt SHARE_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_NO_FUNCTIONS
setopt HIST_NO_STORE
setopt HIST_REDUCE_BLANKS
