# ---- Secrets ----
source ~/.env.secrets

# ---- NVM ----
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"


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

# ---- Git aliases ----
alias gco='git checkout'
alias gp='git pull origin'
alias gpp='git push origin'
alias gcm='git commit -m'
alias gaa='git add .'
alias gs='git status'
alias gb='git branch'
alias gd='git diff'
alias gl='git log --oneline'

# ---- SSH ----
export PATH="/opt/homebrew/opt/openssh/bin:$PATH"

# ---- Ruby (rbenv) ----
eval "$(rbenv init -)"


# ---- Bun ----
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "/Users/rixhy/.bun/_bun" ] && source "/Users/rixhy/.bun/_bun"

# ---- Android SDK ----
export ANDROID_HOME="$HOME/Library/Android/sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin"

# ---- Java 21 ----
export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
export CPPFLAGS="-I/opt/homebrew/opt/openjdk@21/include"
export PATH="$HOME/.local/bin:$PATH"
