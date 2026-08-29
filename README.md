# dotfiles

Personal dotfiles for Linux, built around **Zsh** and **Mise**, adhering strictly to the **XDG Base Directory Specification**.

---

## Highlights

* **Shell (Zsh):**
  * Modular layout loaded via `$ZDOTDIR` (`~/.config/zsh`).
  * Bytecode-compiled (`.zwc`) `compinit` completion system with daily cache regeneration.
  * Fish-like **Autosuggestions** (`zsh-autosuggestions`) and real-time **Syntax Highlighting** (`zsh-syntax-highlighting`).
  * Prefix-based history search via $\uparrow$ / $\downarrow$ arrows.
  * Custom lightweight prompt with Git branch, relative repo paths, porcelain status indicators, and return codes.
  * Untracked local override support (`~/.config/zsh/local.zsh`) for machine-specific tokens and aliases.
* **Version Control (Git):**
  * Global XDG configuration in `~/.config/git/config`.
  * Modern defaults: `zdiff3` conflict style, `histogram` diff algorithm, `colorMoved`, `rebase.autoStash`, `rerere.enabled` (reuse recorded conflict resolutions), and `fetch.prune`.
  * Global ignore rules in `~/.config/git/ignore`.
  * Untracked identity and credentials support via `~/.config/git/config.local`.
* **Tool & Runtime Management ([Mise](https://mise.jdx.dev)):**
  * Declarative configuration in `~/.config/mise/config.toml`.
  * **Runtimes:** Node.js (LTS), Python (3.12), Rust (stable), Bun (latest), uv (latest).
  * **CLI Tools:** `eza`, `fzf`, `zoxide`, `bat`, `ripgrep`, `fd`, `gh`, `jq`.
* **Standard Replacements & Fallbacks:**
  * Modern alternatives for core utilities (`eza` for `ls`, `bat` for `cat`, `rg` for `grep`, `fd` for `find`, `zoxide` for `cd`) with automated fallbacks to POSIX standards if binaries are missing.
  * Dynamic editor detection (`cursor` $\to$ `code` $\to$ `nvim` $\to$ `vim` $\to$ `nano` $\to$ `vi`).
* **Automation & CI/CD:**
  * Standardized styling via `.editorconfig`.
  * Convenience tasks via `Makefile` (`install`, `uninstall`, `lint`, `update`).
  * Automated syntax and static analysis validation (ShellCheck + Zsh/Bash syntax) via GitHub Actions CI.
* **XDG Compliance:**
  * Keeps `$HOME` clean by storing configs in `~/.config`, state/history in `~/.local/state`, cache in `~/.cache`, and data/plugins in `~/.local/share`.

---

## Directory Structure

```text
.
├── .editorconfig           # Coding style and formatting rules
├── .github/
│   └── workflows/
│       └── ci.yml          # GitHub Actions CI workflow
├── Makefile                # Automation commands (install, lint, update)
├── git/
│   ├── config              # Global Git configuration and aliases
│   ├── config.local.example# Template for local user identity
│   └── ignore              # Global gitignore patterns
├── install.sh              # Idempotent installer with automated backups
├── mise/
│   └── config.toml         # Global runtime and tool declarations
├── uninstall.sh            # Safe uninstaller and backup restore
└── zsh/
    ├── .zshenv             # Sets $ZDOTDIR to ~/.config/zsh
    ├── .zshrc              # Modular initialization entrypoint
    ├── local.zsh.example   # Template for private/local environment
    ├── config/
    │   ├── aliases.zsh     # Aliases and CLI replacements
    │   ├── completion.zsh  # Compinit, zstyle, and caching
    │   ├── exports.zsh     # Environment variables and default editor
    │   ├── history.zsh     # History size and behavior
    │   ├── keybindings.zsh # Terminal key mappings and widgets
    │   └── prompt.zsh      # Git-aware custom prompt
    └── integrations/
        ├── fzf.zsh         # Fuzzy finder keybindings and fd source
        ├── mise.zsh        # Mise shell activation
        ├── plugins.zsh     # Autosuggestions & syntax highlighting
        └── zoxide.zsh      # Smarter cd navigation
```

---

## Requirements

* **OS:** Linux / macOS / WSL
* **Base Packages:** `git`, `curl`, `zsh`
* **Font:** Any [Nerd Font](https://www.nerdfonts.com/) (e.g., JetBrainsMono Nerd Font) for prompt glyphs.

---

## Installation

Clone the repository and run the installer:

```bash
git clone https://github.com/guilhermegsr/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

### What `install.sh` does:
1. Backs up any existing non-symlink configurations with timestamps (`.bak.YYYYMMDD_HHMMSS`).
2. Creates symlinks targeting `~/.config/zsh`, `~/.zshenv`, `~/.config/git`, and `~/.config/mise/config.toml`.
3. Installs `mise` if not present on the system.
4. Executes `mise install` to provision all declared tools and runtimes.
5. Clones essential Zsh plugins (`zsh-autosuggestions` & `zsh-syntax-highlighting`) to `~/.local/share/zsh/plugins`.
6. Updates the default shell to `zsh` via `chsh` if necessary.

---

## Uninstallation

To remove all symlinks, restore previous backups, and revert the default shell to Bash:

```bash
./uninstall.sh
```

---

## Automation (Makefile)

If `make` is installed on your system, you can use the following commands:

* `make install` - Runs the installer (`./install.sh`).
* `make uninstall` - Reverts symlinks and restores backups (`./uninstall.sh`).
* `make lint` - Validates syntax for all Bash and Zsh scripts.
* `make update` - Upgrades tools via Mise and pulls latest versions of Zsh plugins.
