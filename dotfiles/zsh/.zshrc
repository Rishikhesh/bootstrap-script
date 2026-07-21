# ---- Secrets ----
source ~/.env.secrets

# ---- Homebrew prefix (cached once) ----
BREW_PREFIX="$(brew --prefix 2>/dev/null)"

# ---- Clean full-screen Ghostty intro + static system stats ----
# Narrow or short splits skip the animation and stay clean.
if [[ -o interactive && $TERM_PROGRAM == ghostty ]] \
  && (( ${COLUMNS:-0} >= 100 && ${LINES:-0} >= 22 )); then
  zsh ~/.config/fastfetch/ghostty-intro.zsh
fi

# ---- NVM ----
export NVM_DIR="$HOME/.nvm"

load-nvm() {
  (( ${NVM_IS_LOADED:-0} )) && return 0

  local nvm_script="$BREW_PREFIX/opt/nvm/nvm.sh"

  [[ -s "$nvm_script" ]] || {
    print -u2 "NVM is not installed at $nvm_script"
    return 1
  }

  # Remove the command shims before NVM adds Node to PATH.
  unfunction nvm node npm npx corepack yarn pnpm 2>/dev/null
  \. "$nvm_script" || return
  typeset -g NVM_IS_LOADED=1
}

# Load NVM only when a Node command is used.
nvm()      { load-nvm || return; nvm "$@"; }
node()     { load-nvm || return; command node "$@"; }
npm()      { load-nvm || return; command npm "$@"; }
npx()      { load-nvm || return; command npx "$@"; }
corepack() { load-nvm || return; command corepack "$@"; }
yarn()     { load-nvm || return; command yarn "$@"; }
pnpm()     { load-nvm || return; command pnpm "$@"; }

# ---- Auto .nvmrc ----
autoload -U add-zsh-hook

load-nvmrc() {
  local nvmrc_path="$PWD/.nvmrc"
  [[ -f "$nvmrc_path" ]] || return

  load-nvm || return

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

# ---- Fuzzy finding (fd + fzf + bat) ----
export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git --exclude node_modules'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --strip-cwd-prefix --hidden --follow --exclude .git --exclude node_modules'
export FZF_DEFAULT_OPTS='--height=60% --layout=reverse --border=rounded --info=inline --prompt="> " --pointer=">" --marker=">" --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc,marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8'
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:500 {}' --preview-window=right:60%:wrap"
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always --icons {}' --preview-window=right:60%:wrap"

_fzf_compgen_path() {
  fd --hidden --follow --exclude .git --exclude node_modules . "$1"
}

_fzf_compgen_dir() {
  fd --type d --hidden --follow --exclude .git --exclude node_modules . "$1"
}

[[ -r "$BREW_PREFIX/opt/fzf/shell/completion.zsh" ]] && source "$BREW_PREFIX/opt/fzf/shell/completion.zsh"
[[ -r "$BREW_PREFIX/opt/fzf/shell/key-bindings.zsh" ]] && source "$BREW_PREFIX/opt/fzf/shell/key-bindings.zsh"

# ---- Smart directory jumping ----
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# ---- File viewing (bat) ----
alias cat='bat --paging=never'

# ---- System info (manual flex) ----
alias ff='fastfetch'

# ---- Listing (eza) ----
alias ls='eza --icons --group-directories-first'
alias ll='eza -lah --header --icons --git --hyperlink=always --color-scale=age,size --group-directories-first'
alias la='eza -a --icons --group-directories-first'
alias lt='eza --tree --level=3 --git-ignore --icons --hyperlink=always'
alias lc='eza --code --git-ignore'
alias lr='eza -lah --sort=modified --reverse --icons --group-directories-first'
alias ld='eza --only-dirs --icons --group-directories-first'

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
