# dotfiles

> Fast, modular, and strictly XDG-compliant environment built with **Zsh**, **Mise**, **Tmux**, and **Alacritty**.

---

## Quick Start

```bash
git clone https://github.com/guilhermegsr/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

---

## Core Stack

| Component | Tool | Highlights |
| :--- | :--- | :--- |
| **Shell** | [Zsh](https://www.zsh.org/) | Modular layout, bytecode compilation (`.zwc`), daily completion caching, custom Git prompt with latency timer |
| **Multiplexer** | [Tmux](https://github.com/tmux/tmux) | Omarchy-inspired top status bar (`●`), `Ctrl+b` prefix, arrow navigation, automatic window naming, `Alt+1..9` tabs |
| **Terminal** | [Alacritty](https://alacritty.org/) | GPU-accelerated, JetBrainsMono Nerd Font (11px), `Beam` cursor shape |
| **Toolchains** | [Mise](https://mise.jdx.dev/) | Declarative runtime management (`Node.js`, `Python`, `Rust`, `Bun`, `uv`, `tmux`, `shellcheck`) |
| **Modern CLI** | Core Utilities | `eza` (ls), `bat` (cat), `ripgrep` (grep), `fd` (find), `zoxide` (cd), `fzf` (fuzzy search) |
| **VCS** | [Git](https://git-scm.com/) | XDG config, `zdiff3` conflict style, `histogram` diff, `rerere`, `fetch.prune`, automatic remote setup |

---

## Built-in Utilities & Keybindings

### Zsh Helpers
* `mkcd <dir>` — Create directory and `cd` into it in one command.
* `extract <archive>` — Universal extractor for `.tar.*`, `.zip`, `.7z`, `.rar`, and `.tar.zst`.
* `port <port>` — Show process listening on a given network port (`lsof` / `ss` / `netstat`).
* `myip` — Display local network IP and public IP.
* `git-clean-branches` — Interactively prune local branches already merged into upstream default branch.

### Tmux Shortcuts
* `Ctrl+b` $\to$ `|` / `-` — Split pane vertically / horizontally (preserves active directory).
* `Ctrl+b` $\to$ `H` / `V` — Force layout to even horizontal (columns) / even vertical (rows).
* `Ctrl+b` $\to$ `Espaço` — Cycle through all 5 pane layouts.
* `Ctrl+b` $\to$ `c` — New window (auto-named by active process).
* `Ctrl+b` $\to$ `,` — Rename active window manually.
* `Ctrl+b` $\to$ `.` — Restore automatic window renaming.
* `Alt+1` .. `Alt+9` — Switch directly to window $N$ without prefix.
* `Alt + Arrows` — Navigate panes directly without prefix.

---

## Directory Layout

```text
.
├── Makefile                # Automation entrypoints (install, update, lint)
├── alacritty/              # Terminal font and cursor configuration
├── git/                    # Global Git configuration, ignores, and local template
├── install.sh              # Idempotent deployment script with automated font setup
├── mise/                   # Global CLI tools and runtime declarations
├── tmux/                   # Minimalist top-bar Tmux configuration
├── uninstall.sh            # Safe teardown and backup restoration script
└── zsh/
    ├── .zshenv             # Sets $ZDOTDIR to ~/.config/zsh
    ├── .zshrc              # Modular initialization loader
    ├── config/             # Aliases, completions, exports, functions, history, prompt
    └── integrations/       # Fzf, Mise, plugins (autosuggestions/syntax-highlighting), Zoxide
```

---

## Management

```bash
make install    # Deploy symlinks, provision font, and install Mise tools
make update     # Upgrade Mise tools and pull latest Zsh plugins
make lint       # Validate syntax and run ShellCheck analysis
make uninstall  # Revert symlinks and restore original files
```
