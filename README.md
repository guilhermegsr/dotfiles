# dotfiles

> Fast, modular, and strictly XDG-compliant environment built with **Zsh**, **Mise**, **Tmux**, **OpenSSH**, and **Alacritty**.

---

## Quick Start

```bash
git clone https://github.com/guilhermegsr/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
make install
```

During installation, the installer will interactively prompt for:
1. **Existing Backup Restoration**: Optionally restore an existing backup archive (`.tar.gz` or encrypted `.tar.gz.enc`).
2. **Git Author Name & Email**: Automatically provisions `~/.config/git/config.local` (or reuses restored identity).
3. **Personal SSH Key Generation**: Optionally creates an `ed25519` key in `~/.ssh/keys/personal/` (or skips if keys already exist/were restored).

---

## Core Stack

| Component | Tool | Highlights |
| :--- | :--- | :--- |
| **Shell** | [Zsh](https://www.zsh.org/) | Modular layout, bytecode compilation (`.zwc`), daily completion caching, custom Git prompt with latency timer |
| **SSH** | [OpenSSH](https://www.openssh.com/) | Structured `~/.ssh/keys/{personal,work,servers}`, connection multiplexing (`ControlMaster`), automated permissions |
| **VCS** | [Git](https://git-scm.com/) | XDG config, `zdiff3` conflict style, `histogram` diff, `rerere`, `fetch.prune`, automatic remote setup |
| **Multiplexer** | [Tmux](https://github.com/tmux/tmux) | Omarchy-inspired top status bar (`●`), `Ctrl+b` prefix, arrow navigation, automatic window naming, `Alt+1..9` tabs |
| **Terminal** | [Alacritty](https://alacritty.org/) | GPU-accelerated, JetBrainsMono Nerd Font (11px), `Beam` cursor shape |
| **Toolchains** | [Mise](https://mise.jdx.dev/) | Declarative runtime management (`Node.js`, `Python`, `Rust`, `Bun`, `uv`, `tmux`, `shellcheck`) |
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
  # Prompts for optional AES-256-CBC password encryption via OpenSSL
  ```

* **Restore a backup**:
  ```bash
  make restore
  # Prompts for backup file path, decrypts if necessary, and enforces strict POSIX permissions (0700/0600/0644)
  ```

---

## Directory Layout

```text
.
├── Makefile                # Automation entrypoints (install, backup, restore, update, lint)
├── alacritty/              # GPU-accelerated terminal configuration
├── backup.sh               # Secure archive utility for untracked secrets and SSH keys
├── git/                    # Global Git configuration, ignores, and local template
│   ├── config              # Global settings (histogram diff, zdiff3, rerere)
│   ├── config.local.example# Template for personal name/email
│   └── ignore              # Global ignores (OS, IDEs, caches, local secrets)
├── install.sh              # Idempotent deployment script with automated font & SSH setup
├── mise/                   # Global CLI tools and runtime declarations (config.toml)
├── restore.sh              # Safe restoration utility with automatic permission hardening
├── ssh/                    # SSH client configuration and templates
│   ├── config              # Global defaults, ControlMaster multiplexing, Git routing
│   └── config.local.example# Template for corporate hosts, bastions, and tunnels
├── tmux/                   # Minimalist top-bar Tmux configuration (tmux.conf)
├── uninstall.sh            # Safe teardown and backup restoration script
└── zsh/
    ├── .zshenv             # Sets $ZDOTDIR to ~/.config/zsh
    ├── .zshrc              # Modular initialization loader
    ├── local.zsh.example   # Template for local environment variables & tokens
    ├── config/             # Aliases, completions, exports, functions, history, prompt
    └── integrations/       # Fzf, Mise, plugins (autosuggestions/syntax-highlighting), Zoxide
```

---

## Management

```bash
make install    # Deploy symlinks, provision font, and install Mise tools
make backup     # Create secure/encrypted archive of local secrets and SSH keys
make restore    # Restore secrets and SSH keys from a backup archive
make update     # Upgrade Mise tools and pull latest Zsh plugins
make lint       # Validate syntax and run ShellCheck analysis
make uninstall  # Revert symlinks and restore original files
```
