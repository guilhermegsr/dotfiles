# dotfiles

Personal dotfiles for Linux, built around **Zsh** and **Mise**, adhering strictly to the **XDG Base Directory Specification**.

---

## Highlights

* **Shell (Zsh):**
  * Modular layout loaded via `$ZDOTDIR` (`~/.config/zsh`).
  * Bytecode-compiled (`.zwc`) `compinit` completion system with daily cache regeneration.
  * Prefix-based history search via $\uparrow$ / $\downarrow$ arrows.
  * Custom lightweight prompt with Git branch, porcelain status indicators, and return codes.
* **Tool & Runtime Management ([Mise](https://mise.jdx.dev)):**
  * Declarative configuration in `~/.config/mise/config.toml`.
  * **Runtimes:** Node.js (LTS), Python (3.12), Rust (stable), Bun (latest), uv (latest).
  * **CLI Tools:** `eza`, `fzf`, `zoxide`, `bat`, `ripgrep`, `fd`, `jq`.
* **Standard Replacements & Fallbacks:**
  * Modern alternatives for core utilities (`eza` for `ls`, `bat` for `cat`, `rg` for `grep`, `fd` for `find`, `zoxide` for `cd`) with automated fallbacks to POSIX standards if binaries are missing.
* **XDG Compliance:**
  * Keeps `$HOME` clean by storing configs in `~/.config`, state/history in `~/.local/state`, and cache in `~/.cache`.

---

## Directory Structure

```text
.
├── install.sh              # Idempotent installer with automated backups
├── uninstall.sh            # Safe uninstaller and backup restore
├── mise/
│   └── config.toml         # Global runtime and tool declarations
└── zsh/
    ├── .zshenv             # Sets $ZDOTDIR to ~/.config/zsh
    ├── .zshrc              # Modular initialization entrypoint
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
2. Creates symlinks targeting `~/.config/zsh`, `~/.zshenv`, and `~/.config/mise/config.toml`.
3. Installs `mise` if not present on the system.
4. Executes `mise install` to provision all declared tools and runtimes.
5. Updates the default shell to `zsh` via `chsh` if necessary.

---

## Uninstallation

To remove all symlinks, restore previous backups, and revert the default shell to Bash:

```bash
./uninstall.sh
```
