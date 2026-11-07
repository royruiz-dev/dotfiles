# Dotfiles

Shell configuration, editor setup, and terminal customization.

## Quick Start

```bash
git clone git@github.com:YOUR_USERNAME/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
exec zsh
```

## Dependencies

### Core (installed by install.sh)

```bash
brew install zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search fzf eza zoxide pyenv
```

### Prompt (install manually if needed)

```bash
brew install powerlevel10k starship
```

### Optional

| Package        | Purpose           | Install                      |
| -------------- | ----------------- | ---------------------------- |
| openjdk@21     | Java 21           | `brew install openjdk@21`    |
| postgresql@15  | PostgreSQL client | `brew install postgresql@15` |

## Structure

| Directory               | Purpose                         | Git     |
| ----------------------- | ------------------------------- | ------- |
| `zsh/.zshrc`            | Main shell config               | Tracked |
| `zsh/functions/`        | General-purpose functions       | Tracked |
| `zsh/functions/archive/`| Archived general-purpose        | Tracked |
| `zsh/configs/`          | Prompt configs (p10k, starship) | Tracked |
| `zsh/local/`            | Machine-specific config         | Ignored |
| `zsh/local/archive/`    | Archived machine-specific       | Ignored |
| `nvim/`                 | Neovim config (Lazy.nvim)       | Tracked |
| `tmux/.tmux.conf`       | Tmux config (TPM plugins)       | Tracked |
| `wezterm/wezterm.lua`     | Wezterm terminal config (core)  | Tracked |
| `wezterm/wezterm.hai.lua` | HAI proxy integration           | Ignored |

## Wezterm

| File                      | Purpose                                  | Git     |
| ------------------------- | ---------------------------------------- | ------- |
| `wezterm/wezterm.lua`     | Core config (keybindings, colors, panes) | Tracked |
| `wezterm/wezterm.hai.lua` | HAI proxy integration (status bar, tabs) | Ignored |

**Where to make changes:**

| Change type                          | File                       |
| ------------------------------------ | -------------------------- |
| Keybindings, colors, fonts, panes    | `wezterm.lua`              |
| HAI proxy indicator, hai tab styling | `wezterm.hai.lua`          |
| New machine-specific wezterm feature | Create new `wezterm.*.lua` |

The main config conditionally loads `wezterm.hai.lua` if present. On machines without it, Cmd+Shift+H is not bound and no hai indicator appears.

## Archiving

| Type                        | Location                 | Git     |
| --------------------------- | ------------------------ | ------- |
| General-purpose functions   | `zsh/functions/archive/` | Tracked |
| Machine-specific functions  | `zsh/local/archive/`     | Ignored |

## Symlinks Created

```text
~/.zshrc              → ~/.dotfiles/zsh/.zshrc
~/.zsh                → ~/.dotfiles/zsh
~/.p10k.zsh           → ~/.dotfiles/zsh/configs/p10k.zsh
~/.config/starship.toml → ~/.dotfiles/zsh/configs/starship.toml
~/.config/nvim        → ~/.dotfiles/nvim
~/.tmux.conf          → ~/.dotfiles/tmux/.tmux.conf
~/.wezterm.lua        → ~/.dotfiles/wezterm/wezterm.lua
```

## Post-Install

### Tmux plugins

Open tmux and press `prefix + I` (Ctrl+a, then I) to install plugins.

### Neovim plugins

Open nvim — Lazy.nvim installs plugins automatically on first launch.

## Usage

```bash
fh list              # Show available help categories
fh claude            # Claude session help
fh utilities         # Utility functions help
```

## Git Workflow

This repo uses two remotes and branches:

| Remote   | Branch | Content                             |
| -------- | ------ | ----------------------------------- |
| `origin` | `main` | Portable config (no local files)    |
| `work`   | `work` | Everything (includes work-specific) |

**General improvements (portable):**

```bash
git checkout main
# make changes to tracked files
git commit -am "description"
git push origin main
git checkout work
git cherry-pick main
git push work work
```

**Work-specific changes:**

```bash
git checkout work
# make changes to local/ or work-specific files
git commit -am "description"
git push work work
```

**Sync specific file from work to main:**

```bash
git checkout main
git checkout work -- path/to/file
git commit -m "description"
git push origin main
```

> **Note:** Don't use `git merge` between branches — the `.gitignore` differs between them. Use `cherry-pick` or checkout specific files instead.
