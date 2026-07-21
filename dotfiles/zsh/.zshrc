# ---- Secrets ----
source ~/.env.secrets

# ---- Homebrew prefix (cached once) ----
BREW_PREFIX="$(brew --prefix 2>/dev/null)"

# ---- Startup banner (ghost + stats) ----
# Only render when the pane is wide enough for side-by-side; narrow splits stay clean.
[[ -o interactive ]] && command -v fastfetch >/dev/null 2>&1 && (( ${COLUMNS:-0} >= 100 )) && fastfetch

# ---- NVM ----
export NVM_DIR="$HOME/.nvm"
[ -s "$BREW_PREFIX/opt/nvm/nvm.sh" ] && \. "$BREW_PREFIX/opt/nvm/nvm.sh"
[ -s "$BREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$BREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm"

# ---- Auto .nvmrc ----
autoload -U add-zsh-hook

load-nvmrc() {
  command -v nvm >/dev/null 2>&1 || return

  local nvmrc_path="$PWD/.nvmrc"
  [[ -f "$nvmrc_path" ]] || return

  local node_version current_version installed_version
  IFS= read -r node_version < "$nvmrc_path"
  node_version="${node_version//[[:space:]]/}"
  [[ -n "$node_version" ]] || return

  current_version="$(nvm current 2>/dev/null)"
  [[ "${current_version#v}" == "${node_version#v}" ]] && return

  installed_version="$(nvm version "$node_version" 2>/dev/null)"
  if [[ "$installed_version" != "N/A" ]]; then
    nvm use --silent "$node_version" >/dev/null
  else
    echo "Installing Node $node_version..."
    nvm install "$node_version"
  fi
}

add-zsh-hook chpwd load-nvmrc
load-nvmrc

# ---- Bun ----
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# ---- SSH (brew openssh) ----
export PATH="$BREW_PREFIX/opt/openssh/bin:$PATH"

# ---- Local bin ----
export PATH="$HOME/.local/bin:$PATH"

# ---- System info (manual flex) ----
alias ff='fastfetch'

# ---- Listing (eza) ----
alias ls='eza --icons --group-directories-first'
alias ll='eza -lah --icons --git --group-directories-first'
alias la='eza -a --icons --group-directories-first'
alias lt='eza --tree --level=2 --icons'

# ---- Git aliases ----
alias gco='git checkout'
alias gpl='git pull origin'
alias gph='git push origin'
alias gcm='git commit -m'
alias gaa='git add .'
alias gs='git status'
alias gb='git branch'
alias gd='git diff'
alias gl='git log --oneline'

# ---- Dotfiles quick-sync ----
alias dots='cd ~/personal/bootstrap-script && git add -A && git commit -m "update dotfiles" && git push'

# ---- Prompt (starship) ----
eval "$(starship init zsh)"

# ---- Autosuggestions + syntax highlighting (keep last) ----
source "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" 2>/dev/null
source "$BREW_PREFIX/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" 2>/dev/null
