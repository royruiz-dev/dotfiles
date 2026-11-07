#!/bin/bash
set -e

DOTFILES="$HOME/.dotfiles"

# Helper: create symlink, prompting if target exists
link() {
    local src="$1"
    local dst="$2"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        echo "Warning: $dst exists and is not a symlink"
        read -p "Remove it? (y/n) " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] || return 1
    fi
    rm -rf "$dst"
    ln -sf "$src" "$dst"
}

echo "Installing dotfiles..."

# 1. Check/install core dependencies
echo "Checking dependencies..."
deps=(zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search fzf eza zoxide pyenv neovim tmux starship powerlevel10k)
for dep in "${deps[@]}"; do
    if ! brew list "$dep" &>/dev/null; then
        echo "Installing $dep..."
        brew install "$dep"
    fi
done

# 2. Create symlinks
echo "Creating symlinks..."
mkdir -p ~/.config

link "$DOTFILES/zsh/.zshrc" ~/.zshrc
link "$DOTFILES/zsh" ~/.zsh
link "$DOTFILES/zsh/configs/p10k.zsh" ~/.p10k.zsh
link "$DOTFILES/zsh/configs/starship.toml" ~/.config/starship.toml
link "$DOTFILES/nvim" ~/.config/nvim
link "$DOTFILES/tmux/.tmux.conf" ~/.tmux.conf
link "$DOTFILES/wezterm/wezterm.lua" ~/.wezterm.lua

# 3. TPM (tmux plugin manager)
if [[ ! -d ~/.tmux/plugins/tpm ]]; then
    echo "Installing TPM..."
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

# 4. fzf keybindings
if [[ ! -f ~/.fzf.zsh ]]; then
    echo "Setting up fzf..."
    "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc
fi

echo ""
echo "Done!"
echo ""
echo "Next steps:"
echo "  1. Run 'exec zsh' to reload shell"
echo "  2. Open tmux and press Ctrl+a, then I to install plugins"
echo "  3. Open nvim — plugins install automatically on first launch"
