# Personal dotfiles

> Personal configuration used to rebuild my environment after formatting or replacing a machine. Built with **Zsh**, **Starship**, **Mise**, **Tmux**, **OpenSSH**, and **Alacritty**.

---

## Quick Start

```bash
git clone https://github.com/guilhermegsr/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
make install
```

To deploy only the configuration while offline, use `make install-offline`. The equivalent direct command is `./install.sh --offline`; add `--no-chsh` if the installer must also leave the login shell unchanged.

During installation, the installer will interactively prompt for:
1. **Existing Backup Restoration**: Optionally restore an existing backup archive (`.tar.gz` or encrypted `.tar.gz.enc`).
2. **Git Author Name & Email**: Automatically provisions `~/.config/git/config.local` (or reuses restored identity).
3. **Personal SSH Key Generation**: Optionally creates an `ed25519` key in `~/.ssh/keys/personal/` (or skips if keys already exist/were restored).

---

## Core Stack

| Component | Tool | Highlights |
| :--- | :--- | :--- |
| **Shell** | [Zsh](https://www.zsh.org/) + [Starship](https://starship.rs/) | Modular layout, bytecode compilation (`.zwc`), daily completion caching, Git-aware prompt with command timer |
| **SSH** | [OpenSSH](https://www.openssh.com/) | Structured `~/.ssh/keys/{personal,work,servers}`, connection multiplexing (`ControlMaster`), automated permissions |
| **VCS** | [Git](https://git-scm.com/) | XDG config, `zdiff3` conflict style, `histogram` diff, `rerere`, `fetch.prune`, automatic remote setup |
| **Multiplexer** | [Tmux](https://github.com/tmux/tmux) | Omarchy-inspired top status bar (`●`), `Ctrl+b` prefix, arrow navigation, automatic window naming, `Alt+1..9` tabs |
| **Terminal** | [Alacritty](https://alacritty.org/) | GPU-accelerated, JetBrainsMono Nerd Font (11px), `Beam` cursor shape |
| **Toolchains** | [Mise](https://mise.jdx.dev/) | Languages pinned to a major series, CLI tools rolling, every release held back 7 days |
| **Modern CLI** | Core Utilities | `eza` (ls), `bat` (cat), `ripgrep` (grep), `fd` (find), `zoxide` (cd), `fzf` (fuzzy search) |

---

## Usage Guide & Examples

### 1. SSH Management

All keys are strictly structured under `~/.ssh/keys/` and auto-routed via `~/.ssh/config`.

* **Generate a new keypair**:
  ```bash
  # Interactive mode (prompts category and email):
  ssh-new

  # Direct generation (creates ~/.ssh/keys/work/id_ed25519 and copies .pub to clipboard):
  ssh-new work my-work-email@company.com
  ```

* **Import and secure a downloaded VPS/cloud key (`.pem`, `.key`, `.pub`)**:
  ```bash
  # Imports to ~/.ssh/keys/servers/vps-prod.pem, applies chmod 600, and extracts .pub
  ssh-import ~/Downloads/aws-instance.pem servers vps-prod.pem
  ```

* **Copy public key to clipboard**:
  ```bash
  pubkey          # Copies personal key (~/.ssh/keys/personal/id_ed25519.pub)
  pubkey work     # Copies work key (~/.ssh/keys/work/id_ed25519.pub)
  pubkey vps-prod # Copies server public key
  ```

* **Inspect & clean SSH connections**:
  ```bash
  ssh-keys        # List active identities in ssh-agent (ssh-add -l)
  ssh-clean       # Purge stale ControlMaster multiplexing sockets
  ```

* **Add private host overrides** in `~/.ssh/config.local` (untracked):
  ```ssh-config
  Host vps-prod
      HostName 203.0.113.50
      User ubuntu
      IdentityFile ~/.ssh/keys/servers/vps-prod.pem
  ```
  Connect with zero boilerplate: `ssh vps-prod`

---

### 2. Git Productivity

* **Status & Logging**:
  ```bash
  git st          # Compact status with branch sync state (status -sb)
  git lg          # Compact graphical commit history graph
  git lga         # Full commit graph across all branches
  ```

* **Commits & Staging**:
  ```bash
  git cm "feat: add user authentication"   # Commit with message
  git ca                                   # Amend latest commit
  git can                                  # Amend staged changes without editing message
  git df                                   # Diff modified files (histogram algorithm)
  git dfs                                  # Diff staged changes
  git unstage <file>                       # Unstage file without losing modifications
  ```

* **Branch Maintenance**:
  ```bash
  git-clean-branches   # Interactively delete local branches already merged into default branch
  ```

---

### 3. Shell & CLI Utilities

* **Navigation & Directories**:
  ```bash
  mkcd my-project/src    # Create nested directories and cd into it in one step
  z my-proj              # Jump to frequently used directories via zoxide
  ```

* **Archives**:
  ```bash
  extract package.tar.gz # Universal extraction (.tar.*, .zip, .7z, .rar, .tar.zst)
  ```

* **System & Network**:
  ```bash
  port 8080              # Inspect process listening on port 8080 (lsof/ss)
  myip                   # Display local network IP and public IP
  ```

* **Modern Replacements**:
  ```bash
  ls / la / tree         # eza with icons and permissions
  cat / batp             # bat with syntax highlighting and line numbers
  rg                     # ripgrep (grep stays as system grep)
  fd                     # fd (find stays as system find)
  z                      # zoxide jumper (cd stays as the builtin)
  ```

---

### 4. Tmux Keybindings

| Shortcut | Action |
| :--- | :--- |
| `Ctrl+b` $\to$ `\|` | Split pane vertically (inherits active working directory) |
| `Ctrl+b` $\to$ `-` | Split pane horizontally (inherits active working directory) |
| `Ctrl+b` $\to$ `H` / `V` | Force layout to even horizontal (columns) / even vertical (rows) |
| `Ctrl+b` $\to$ `Space` | Cycle through all 5 preset pane layouts |
| `Ctrl+b` $\to$ `c` | Create new window (automatically named after running process) |
| `Ctrl+b` $\to$ `,` / `.` | Rename active window manually / restore automatic naming |
| `Alt + 1..9` | Switch directly to window $N$ without prefix |
| `Alt + Arrows` | Navigate adjacent panes directly without prefix |
| `Ctrl+b` $\to$ `[` $\to$ `v` / `y` | Vi copy mode: select and copy to system clipboard (`wl-copy` / `xclip`) |

---

### 5. Secrets & SSH Backup & Restore

Archive and migrate all machine-specific secrets, Git identities, and SSH keys safely:

* **Create a backup**:
  ```bash
  make backup
  # Archives ~/.ssh/keys, ~/.ssh/config.local, ~/.config/git/config.local, and ~/.config/zsh/local.zsh
  # Encryption is on by default (age if available, otherwise OpenSSL AES-256-CBC + PBKDF2 600000)
  # Unencrypted archives are opt-in and contain private keys:
  ./backup.sh --plain ~/dotfiles-backup.tar.gz
  # Existing destinations are protected; replacement must be explicit:
  ./backup.sh --plain --force ~/dotfiles-backup.tar.gz
  ```

* **Restore a backup**:
  ```bash
  make restore
  # Lists archive members, restores only allowlisted paths, and asks for confirmation
  # Rejects '..', absolute paths, symlinks, special files, and unexpected prefixes
  # Decrypts .age / .enc if needed, then enforces POSIX permissions (0700/0600/0644)
  ```

Restore **only archives you created** on a machine you trust. `--plain` backups contain SSH **private keys** in plaintext; treat them like `~/.ssh` itself.

---

## Directory Layout

```text
.
├── Makefile                # Automation entrypoints (install, backup, restore, update, check)
├── alacritty/              # GPU-accelerated terminal configuration
├── backup.sh               # Secure archive utility for untracked secrets and SSH keys
├── git/                    # Global Git configuration, ignores, and local template
│   ├── config              # Shared settings, included by ~/.config/git/config (histogram diff, zdiff3, rerere)
│   ├── config.local.example# Template for personal name/email
│   └── ignore              # Global ignores (OS, IDEs, caches, local secrets)
├── install.sh              # Idempotent deployment with pinned plugins, fonts, and Mise
├── locks/                  # Pinned plugin SHAs and bootstrap artifact checksums
├── mise/                   # Toolchains and CLI tools; version selectors live in config.toml
├── restore.sh              # Allowlisted restoration with permission hardening
├── scripts/                # Doctor, maintenance helpers and regression tests
│   ├── install/            # Config, plugin, font, Mise, shell and onboarding modules
│   └── uninstall/          # Ownership-aware purge implementation
├── ssh/                    # SSH client configuration and templates
│   ├── config              # Global defaults, ControlMaster multiplexing, Git routing
│   └── config.local.example# Template for corporate hosts, bastions, and tunnels
├── starship/               # Cross-shell prompt using the official Nerd Font Symbols preset
├── tmux/                   # Minimalist top-bar Tmux configuration (tmux.conf + copy.sh)
├── uninstall.sh            # Safe teardown with optional ownership-aware purge
└── zsh/
    ├── .zshenv             # Sets $ZDOTDIR to ~/.config/zsh
    ├── .zshrc              # Modular initialization loader
    ├── local.zsh.example   # Template for local environment variables & tokens
    ├── config/             # Aliases, completions, exports, functions, history
    └── integrations/       # Fzf, Mise, Starship, plugins and Zoxide
```

Machine-specific secrets are **not** stored in this repository. After install, `~/.config/zsh/local.zsh` and `~/.config/git/config.local` are regular files in those directories (the repo only provides templates).

### Global Git config layout

`~/.config/git/config` is **not** a symlink into this repository. The installer writes it as a machine-local file that only includes the other two:

```ini
[include]
	path = ~/.dotfiles/git/config    # shared settings, versioned
[include]
	path = config.local              # identity and credential helpers, untracked
```

Everything written by `git config --global` — including what tools such as `gh auth setup-git`, `git lfs install` or IDE extensions write on your behalf — lands in that machine-local file and never reaches the working tree. Put identity and credential helpers in `config.local`; put settings you want on every machine in `git/config`. `make doctor` fails if the global config drifts back to a symlink, if the include is missing, or if `git/config` picks up machine-specific absolute paths.

---

## Management

```bash
make install          # Deploy symlinks, provision font, and install Mise tools
make install-offline  # Deploy configs without network downloads or tool installation
make doctor           # Diagnose links, permissions, configs and managed runtimes
make backup           # Create encrypted archive of local secrets and SSH keys
make restore          # Restore secrets and SSH keys from a backup archive
make update           # Bump plugin/bootstrap pins (not the Mise tools)
make check            # Lint plus backup/restore and shell-helper tests (what CI runs)
make test             # Alias for check
make lint             # Validate syntax and run ShellCheck analysis
make uninstall        # Revert symlinks and restore original files
```

`make doctor` is read-only. It reports broken links, unsafe SSH permissions, invalid Bash/Zsh/TOML/Git configuration, plugin drift, and missing runtime components. Warnings such as an intentionally uninstalled Starship do not fail the command; structural or permission errors do.

For a normal removal, use `make uninstall`. To additionally remove clean plugin checkouts and the Mise bootstrap binary recorded as created by this repository, run `./uninstall.sh --purge`. Purge refuses unregistered plugins, changed Git origins, dirty checkouts, modified binaries, and unsafe ownership manifests. Mise-managed tool versions are deliberately preserved.

Plugin SHAs and bootstrap artifacts remain pinned and checksummed. Run `make update` to refresh those pins and review the diff before committing. It does **not** touch the Mise tools; those follow the rules below.

### How tool versions move

`mise/config.toml` pins each language to the series that gates breaking changes (`node = "26"`, `go = "1.27"`, `python = "3.14"`, `java = "25"`, `bun = "1"`), while ancillary CLI tools stay on `latest`. Two commands cover every update:

```bash
mise outdated   # what has a newer version available
mise upgrade    # move to the newest release inside the current selector
```

`mise upgrade` never crosses a pin: with `node = "26"` it walks 26.x and stops there. Crossing one is a deliberate act — edit `mise/config.toml`, or run `mise upgrade --bump`, which rewrites the selector for you. Either way the new major lands in a diff you review and commit, instead of arriving unannounced.

`minimum_release_age = "7d"` holds every release back for a week before Mise will select it, so a compromised publish has time to be noticed and pulled before it can reach this machine. It applies to pinned and rolling selectors alike: with the quarantine on, `mise latest node@26` resolves to the newest 26.x that is at least seven days old. Already-installed versions are never downgraded by it.

The quarantine is a delay, not a lockfile: two machines installing on different days can still land on different patch releases. Enabling `lockfile` in `[settings]` is the next step up if you want them byte-identical, at the cost of a `mise.lock` to track and refresh.

The Starship configuration is the official Nerd Font Symbols preset. Refresh it from the repository root with `starship preset nerd-font-symbols -o starship/starship.toml`.

`~/.config/zsh/local.zsh`, `~/.config/git/config` and `~/.config/git/config.local` stay as regular files (not repo symlinks), same idea as `~/.ssh/config.local`. `make uninstall` removes only the dotfiles include from `~/.config/git/config` and leaves the rest of the file alone.
