#!/usr/bin/env bash
set -euo pipefail

log()  { printf "\n\033[1;32m%s\033[0m\n" "$*"; }
warn() { printf "\n\033[1;33m%s\033[0m\n" "$*"; }

[[ "$(uname -s)" == "Darwin" ]] || { echo "macOS only"; exit 1; }

append_block_once() {
  local file="$1"
  local begin="$2"
  local end="$3"
  local content="$4"

  touch "$file"
  if grep -qF "$begin" "$file" 2>/dev/null; then
    log "Block already present in $(basename "$file") — skipping"
  else
    log "Appending block to $(basename "$file")"
    {
      echo ""
      echo "$begin"
      echo "$content"
      echo "$end"
    } >> "$file"
  fi
}

brew_install() {
  brew list --formula "$1" >/dev/null 2>&1 || brew install "$1"
}

brew_cask_install() {
  brew list --cask "$1" >/dev/null 2>&1 || brew install --cask "$1"
}

# ----------------------------
# Xcode CLI Tools
# ----------------------------
if ! xcode-select -p >/dev/null 2>&1; then
  warn "Installing Xcode Command Line Tools..."
  xcode-select --install || true
else
  log "Xcode Command Line Tools already installed"
fi

# ----------------------------
# Homebrew
# ----------------------------
if ! command -v brew >/dev/null 2>&1; then
  log "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    grep -q 'brew shellenv' ~/.zprofile 2>/dev/null || \
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)" || true
  fi
else
  log "Homebrew already installed"
fi

brew update

# ----------------------------
# CLI tools
# ----------------------------
log "Installing CLI tools..."
brew_install git
brew_install openssh
brew_install nvm

# ----------------------------
# GUI apps
# ----------------------------
log "Installing GUI apps..."
brew_cask_install arc
brew_cask_install cursor
brew_cask_install warp
brew_cask_install raycast
brew_cask_install docker
brew_cask_install rectangle
brew_cask_install postman-agent   # ✅ Postman Agent

brew cleanup || true

# ----------------------------
# NVM setup (manual per repo)
# ----------------------------
log "Configuring nvm..."
mkdir -p ~/.nvm

NVM_BEGIN="# >>> NVM (bootstrap-mac) >>>"
NVM_END="# <<< NVM (bootstrap-mac) <<<"
NVM_CONTENT='export NVM_DIR="$HOME/.nvm"
# Apple Silicon Homebrew
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh"
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && . "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
# Intel Homebrew
[ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"
[ -s "/usr/local/opt/nvm/etc/bash_completion.d/nvm" ] && . "/usr/local/opt/nvm/etc/bash_completion.d/nvm"'

append_block_once "$HOME/.zshrc" "$NVM_BEGIN" "$NVM_END" "$NVM_CONTENT"

# Load nvm for this run
export NVM_DIR="$HOME/.nvm"
if [[ -s "/opt/homebrew/opt/nvm/nvm.sh" ]]; then
  . "/opt/homebrew/opt/nvm/nvm.sh"
elif [[ -s "/usr/local/opt/nvm/nvm.sh" ]]; then
  . "/usr/local/opt/nvm/nvm.sh"
fi

# Install LTS baseline
if command -v nvm >/dev/null 2>&1; then
  nvm install --lts >/dev/null
  nvm use --lts >/dev/null
  nvm alias default lts/* >/dev/null
  log "Default Node (LTS): $(node -v)"
else
  warn "nvm not available yet — restart terminal after script completes"
fi

# ----------------------------
# Git config
# ----------------------------
log "Configuring git..."
if ! git config --global user.name >/dev/null; then
  read -r -p "Git user.name: " GIT_NAME
  git config --global user.name "$GIT_NAME"
fi

if ! git config --global user.email >/dev/null; then
  read -r -p "Git user.email: " GIT_EMAIL
  git config --global user.email "$GIT_EMAIL"
fi

git config --global init.defaultBranch main
git config --global fetch.prune true
git config --global pull.rebase false

# ----------------------------
# SSH setup (idempotent)
# ----------------------------
log "Setting up SSH..."
mkdir -p ~/.ssh
chmod 700 ~/.ssh

KEY="$HOME/.ssh/id_ed25519"
EMAIL="$(git config --global user.email || echo git@local)"

if [[ ! -f "$KEY" ]]; then
  ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY"
else
  log "SSH key already exists"
fi

eval "$(ssh-agent -s)" >/dev/null
ssh-add --apple-use-keychain "$KEY" 2>/dev/null || ssh-add "$KEY" || true

SSH_CFG="$HOME/.ssh/config"
touch "$SSH_CFG"
chmod 600 "$SSH_CFG"

SSH_BEGIN="# >>> GITHUB SSH (bootstrap-mac) >>>"
SSH_END="# <<< GITHUB SSH (bootstrap-mac) <<<"
SSH_CONTENT='Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  AddKeysToAgent yes
  UseKeychain yes'

append_block_once "$SSH_CFG" "$SSH_BEGIN" "$SSH_END" "$SSH_CONTENT"

if command -v pbcopy >/dev/null 2>&1; then
  cat "${KEY}.pub" | pbcopy
  log "SSH public key copied to clipboard ✅"
else
  log "SSH public key:"
  cat "${KEY}.pub"
fi

log "Bootstrap complete 🎉 (safe to re-run)"
echo "Next steps:"
echo "  1) Add SSH key to GitHub → Settings → SSH & GPG keys"
echo "  2) Test: ssh -T git@github.com"
echo "  3) Open Docker Desktop, Rectangle, and Postman Agent once (macOS permissions)"
echo "  4) Restart terminal (Warp)"
echo "  5) Per repo: run 'nvm install' / 'nvm use' when .nvmrc is present"
