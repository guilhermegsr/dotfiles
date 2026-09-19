# Personal dotfiles

> What I use to rebuild a machine after a format: **Zsh**, **Starship**, **Mise**, **Tmux**, **OpenSSH**, **Alacritty**.

```bash
git clone https://github.com/guilhermegsr/dotfiles.git ~/.dotfiles
cd ~/.dotfiles && make install
```

`make install` is idempotent. It links the configs, installs the pinned Zsh plugins, the JetBrains Mono Nerd Font and Mise, then asks three things: restore a backup, Git identity, generate an SSH key. Answering nothing leaves templates behind. `make install-offline` skips every download; `--no-chsh` leaves the login shell alone.

## What it sets up

| | |
| :--- | :--- |
| **Shell** | Modular Zsh under `~/.config/zsh`, Starship prompt, autosuggestions and syntax highlighting pinned by commit |
| **Tools** | Mise: languages pinned to a major series, CLI tools rolling, nothing installed until it has been public for 7 days |
| **SSH** | `~/.ssh/keys/{personal,work,servers}`, connection multiplexing, `conf.d/` and `config.local` for private hosts |
| **Git** | Shared settings in this repo; identity and credential helpers in `~/.config/git/config.local` |
| **Terminal** | Alacritty and Tmux: top status bar, `Alt+1..9` for windows, `Alt+arrows` between panes, `|` and `-` to split, `Ctrl+b r` to reload |

## Commands

```bash
make install    # deploy everything (install-offline: no downloads)
make doctor     # diagnose links, permissions, configs, plugins, credential helpers
make backup     # encrypted archive of secrets and SSH keys
make restore    # restore from an archive
make update     # bump plugin and bootstrap pins
make check      # lint plus the test suite (what CI runs)
make uninstall  # revert symlinks, keep local files (--purge also drops managed assets)
```

Shell helpers: `ssh-new [personal|work|servers]`, `ssh-import <key> <category>`, `pubkey [name]`, `ssh-clean`, `extract <archive>`, `mkcd <dir>`, `port <n>`, `myip`, `git-clean-branches`. Git aliases: `st`, `lg`, `cm`, `ca`, `can`, `df`, `dfs`, `unstage`, `last`.

## Backup and restore

```bash
make backup                  # or ./backup.sh [--passphrase|--plain] [--force] [path]
make restore                 # or ./restore.sh [--yes] <archive>
```

Covers `~/.ssh/keys`, `~/.ssh/config.local`, `~/.ssh/conf.d`, `~/.config/git/config.local` and `~/.config/zsh/local.zsh`.

With `age` installed the archive is encrypted **to your public key** (`~/.ssh/keys/personal/id_ed25519.pub`), so restoring needs the matching private key and nothing you have to remember — which is the point, since the machine being rebuilt is the one that had the passphrase. Add spare public keys to `~/.ssh/age-recipients` to keep a second way in: age cannot combine a key and a passphrase in one archive, so a spare key is the only recovery path. `--passphrase` forces passphrase encryption, `--plain` skips it and writes your private keys in the clear.

Restore only writes allowlisted paths, and refuses `..`, absolute paths, symlinks inside the archive, special files, and destinations that are already symlinks. The tarball is streamed straight into the encryptor, so the keys never touch the disk unencrypted.

## Global Git config

`~/.config/git/config` is **not** a symlink into this repository. The installer writes it as a machine-local file that includes the other two:

```ini
[include]
	path = ~/.dotfiles/git/config    # shared settings, versioned
[include]
	path = config.local              # identity and credential helpers, untracked
```

So everything `git config --global` writes — including what `gh auth setup-git` or an IDE writes on your behalf — lands outside the working tree. `make doctor` fails if that drifts back to a symlink, and warns when a credential helper points into a versioned Mise install (it breaks on the next upgrade) or relies on `PATH` (it breaks outside an interactive shell).

## Versions

Languages pin the series that gates breaking changes (`node = "26"`, `go = "1.27"`, `python = "3.14"`, `java = "25"`, `bun = "1"`); CLI tools roll.

```bash
mise outdated   # what has a newer version available
mise upgrade    # move inside the current pin (--bump crosses it and rewrites the selector)
```

`minimum_release_age = "7d"` keeps a fresh release from being selected for a week, so a compromised publish has time to be pulled. `not_found_auto_install = false` keeps a tool probe from turning into an install: opening a terminal never provisions the machine, `mise install` does.

`make update` refreshes `locks/` — plugin commits and the Mise and font checksums — under the same seven-day floor. It does not touch the Mise tools. Review the diff before committing.

## Layout

```text
install.sh uninstall.sh backup.sh restore.sh   # entrypoints, all idempotent
locks/        # pinned plugin commits and bootstrap checksums
scripts/      # doctor, lock maintenance, tests, install/ and uninstall/ modules
zsh/          # .zshenv, .zshrc, config/ and integrations/
git/ ssh/ mise/ tmux/ alacritty/ starship/     # per-tool configuration
```

`make doctor` changes nothing it manages, and is the fastest way to find what drifted. Machine-specific values live in `~/.config/zsh/local.zsh`, `~/.config/git/config.local` and `~/.ssh/config.local` — never in this repository.
