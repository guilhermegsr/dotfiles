# Dotfiles

Zsh, Starship, Mise, Tmux, OpenSSH and Alacritty — what I use to rebuild a machine after a format.

```bash
git clone https://github.com/guilhermegsr/dotfiles.git ~/.dotfiles
cd ~/.dotfiles && make install
```

`make install` is idempotent. It links the configs, installs the pinned Zsh plugins, the JetBrains Mono Nerd Font and Mise, then asks three things: restore a backup, Git identity, generate an SSH key. Answering nothing leaves templates behind. Add `--with-packages` for the few system packages Mise cannot provide; it needs `sudo` and installs only what is missing.

## Commands

```bash
make install    # install-offline skips every download
make doctor     # links, permissions, configs, plugins, credential helpers
make backup     # encrypted archive of secrets and SSH keys
make restore    # restore from an archive
make update     # bump plugin and bootstrap pins
make check      # lint and tests (what CI runs)
make uninstall  # revert symlinks; --purge also drops managed assets
```

Shell helpers: `ssh-new`, `ssh-import`, `pubkey`, `ssh-clean`, `extract`, `mkcd`, `port`, `myip`, `git-clean-branches`.

Tmux: `Alt+1..9` for windows, `Alt+arrows` between panes, `|` and `-` to split, `Ctrl+b r` to reload.

## Layout

```text
zsh/ git/ ssh/ mise/ tmux/ alacritty/ starship/   # per-tool configuration
locks/      # pinned plugin commits and bootstrap checksums
packages/   # system packages per manager, for --with-packages
scripts/    # doctor, lock maintenance, tests, install/ and uninstall/ modules
```

Machine-specific values live in `~/.config/zsh/local.zsh`, `~/.config/git/config.local` and `~/.ssh/config.local` — never in this repository.

## Worth knowing

**The global Git config is not a symlink.** The installer writes `~/.config/git/config` as a real file that includes this repository's `git/config` and a local `config.local`. So everything `git config --global` writes — including what `gh auth setup-git` or an IDE writes on your behalf — lands outside the working tree. `make doctor` fails if that drifts back to a symlink, and warns when a credential helper points into a versioned Mise install or relies on `PATH`.

**Languages pin a series, CLI tools roll.** `node = "26"`, `go = "1.27"`, `python = "3.14"` — crossing a pin is a deliberate edit. `minimum_release_age = "7d"` keeps a fresh release from being selected for a week, and `make update` bumps the plugin and bootstrap pins under the same floor. `not_found_auto_install = false`: opening a terminal never provisions the machine, `mise install` does.

**Backups are encrypted to your SSH key.** With `age` installed the archive goes to `~/.ssh/keys/personal/id_ed25519.pub`, so restoring needs the matching private key and nothing you have to remember — the machine being rebuilt is the one that had the passphrase. Add spare public keys to `~/.ssh/age-recipients` to keep a second way in. It covers `~/.ssh/keys`, `~/.ssh/config.local`, `~/.ssh/conf.d`, `~/.config/git/config.local` and `~/.config/zsh/local.zsh`; restore writes allowlisted paths only, and keeps a timestamped copy of anything it replaces.
