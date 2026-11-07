# ~/.zshrc
# Disable Powerlevel10k instant prompt warning about console output
typeset -g POWERLEVEL9K_INSTANT_PROMPT=off

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ~/bin takes precedence over system binaries for user-managed tools (e.g., fly CLI)
export PATH="$HOME/bin:$PATH"

# history settings (must be set before any plugin that uses history)
HISTFILE=$HOME/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt share_history          # share history between zsh sessions
setopt inc_append_history     # append incrementally (not only on exit)
setopt hist_expire_dups_first # when full, expire duplicates first
setopt hist_ignore_dups       # don't record a line if same as last executed
setopt hist_reduce_blanks     # removes excess spaces before saving to history
setopt hist_verify            # show history command before executing
setopt extended_history       # save timestamps


# Source modularized functions from ~/.zsh/functions/ directory
for file in ~/.zsh/functions/*.zsh; do
  source "$file"
done

# Machine-specific config (not git-tracked)
if [[ -d ~/.zsh/local ]]; then
  for f in ~/.zsh/local/*.zsh(N); do source "$f"; done
fi

# Load Powerlevel10k theme
source $(brew --prefix)/share/powerlevel10k/powerlevel10k.zsh-theme

# Load p10k configuration
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# Plugins
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source $(brew --prefix)/share/zsh-history-substring-search/zsh-history-substring-search.zsh
HISTORY_SUBSTRING_SEARCH_PREFIXED=1
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND='underline'
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND='fg=red,underline'
HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1

# Enable keyboard-based text selection
stty -ixon                    # disable terminal flow control
bindkey -e                    # use Emacs-style keybindings (safe with p10k)
bindkey '^S' set-mark-command # Ctrl+S starts text selection

# Delete selected region
bindkey '^W' kill-region

# Copy selected region to macOS clipboard, overwrite whatever was there
copy-region-to-clipboard() {
  # Copy into Zsh kill ring first
  zle copy-region-as-kill

  # Reset system clipboard and copy selected text
  if [[ -n $CUTBUFFER ]]; then
    # Clear clipboard first (optional, ensures full overwrite)
    pbcopy < /dev/null
    # Copy the selection
    print -rn -- "$CUTBUFFER" | pbcopy
  fi
}

# Register widget
zle -N copy-region-to-clipboard
bindkey '^Y' copy-region-to-clipboard

# completion using arrow keys (based on history)
# bindkey '^[[A' history-search-backward
# bindkey '^[[B' history-search-forward

# Search history for typed prefix with Up/Down arrows
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

bindkey '^[b' backward-word
bindkey '^[f' forward-word
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line

# fzf key bindings and completion
[ -f $(brew --prefix)/opt/fzf/shell/key-bindings.zsh ] && source $(brew --prefix)/opt/fzf/shell/key-bindings.zsh
[ -f $(brew --prefix)/opt/fzf/shell/completion.zsh ] && source $(brew --prefix)/opt/fzf/shell/completion.zsh

# Ctrl+R for fuzzy history search
bindkey '^R' fzf-history-widget

# Remove Option+C binding
bindkey -r '\ec'

# Option+Shift+C for fuzzy directory picker
bindkey '\eC' fzf-cd-widget

# ---- Eza (better ls) -----
alias ls="eza --icons=always"

eval "$(starship init zsh)"

export PATH="$HOME/Library/Python/3.9/bin:$PATH"

# Java 21 (LTS) - install with: brew install openjdk@21
if [[ -d "$(brew --prefix openjdk@21 2>/dev/null)" ]]; then
  export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
  export PATH="$JAVA_HOME/bin:$PATH"
fi
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=($HOME/.docker/completions $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions
export PATH="$HOME/.local/bin:$PATH"
# PostgreSQL 15 client tools - install with: brew install postgresql@15
if [[ -d "/opt/homebrew/opt/postgresql@15" ]]; then
  export PATH="/opt/homebrew/opt/postgresql@15/bin:$PATH"
fi

# Pyenv configuration for shell environment
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"

# Ensures pyenv Python is in PATH for login shells
eval "$(pyenv init --path)"

# Sets up shims, autocompletion, and version switching for zsh
eval "$(pyenv init - zsh)"

# Unset PYENV_VERSION to allow .python-version files to work
unset PYENV_VERSION

# ---- Zoxide (better cd) ----
# IMPORTANT: Must be at the very end of .zshrc
export _ZO_DOCTOR=0  # Disable zoxide config warning
eval "$(zoxide init zsh)"
# cd wrapper is in ~/.zsh/functions/cd.zsh (strips trailing slashes for zoxide)
