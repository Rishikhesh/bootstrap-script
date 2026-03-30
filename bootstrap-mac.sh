#!/usr/bin/env bash
set -euo pipefail

log()  { printf "\n\033[1;32m%s\033[0m\n" "$*"; }
warn() { printf "\n\033[1;33m%s\033[0m\n" "$*"; }

[[ "$(uname -s)" == "Darwin" ]] || { echo "macOS only"; exit 1; }

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
brew_install bun
brew_install docker
brew_install colima
brew_install stow

# ----------------------------
# GUI apps
# ----------------------------
log "Installing GUI apps..."
brew_cask_install arc
brew_cask_install cursor
brew_cask_install warp
brew_cask_install raycast
brew_cask_install rectangle
brew_cask_install bruno

brew cleanup || true

# ----------------------------
# NVM + Node LTS
# ----------------------------
log "Configuring NVM..."
mkdir -p ~/.nvm
export NVM_DIR="$HOME/.nvm"

if [[ -s "/opt/homebrew/opt/nvm/nvm.sh" ]]; then
  . "/opt/homebrew/opt/nvm/nvm.sh"
elif [[ -s "/usr/local/opt/nvm/nvm.sh" ]]; then
  . "/usr/local/opt/nvm/nvm.sh"
fi

if command -v nvm >/dev/null 2>&1; then
  nvm install --lts >/dev/null
  nvm use --lts >/dev/null
  nvm alias default lts/* >/dev/null
  log "Default Node (LTS): $(node -v)"
else
  warn "nvm not available yet — restart terminal after script completes"
fi

# ----------------------------
# SSH key (auth + signing)
# ----------------------------
log "Setting up SSH..."
mkdir -p ~/.ssh
chmod 700 ~/.ssh

KEY="$HOME/.ssh/id_ed25519_personal"

if [[ ! -f "$KEY" ]]; then
  read -r -p "Email for SSH key: " SSH_EMAIL
  ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f "$KEY"
else
  log "SSH key already exists: $KEY"
fi

eval "$(ssh-agent -s)" >/dev/null
ssh-add --apple-use-keychain "$KEY" 2>/dev/null || ssh-add "$KEY" || true

# ----------------------------
# Symlink dotfiles (Stow)
# ----------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

log "Linking dotfiles with Stow..."
touch "$HOME/.env.secrets"

# Back up existing files that would conflict with Stow
for f in .zshrc .ssh/config; do
  target="$HOME/$f"
  if [[ -e "$target" && ! -L "$target" ]]; then
    backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
    warn "Backing up $target → $backup"
    mv "$target" "$backup"
  fi
done

stow -d "$SCRIPT_DIR" -t "$HOME" dotfiles
chmod 600 "$HOME/.ssh/config"
log "Dotfiles linked"

# ----------------------------
# Git config (personal)
# ----------------------------
log "Configuring git..."
git config --global user.name "rishikhesh"
git config --global user.email "rishiyashvanth@gmail.com"
git config --global init.defaultBranch beta
git config --global fetch.prune true
git config --global pull.rebase true
git config --global gpg.format ssh
git config --global commit.gpgsign true
git config --global user.signingkey "$KEY.pub"

# ----------------------------
# Start Colima
# ----------------------------
if command -v colima >/dev/null 2>&1; then
  if ! colima status >/dev/null 2>&1; then
    log "Starting Colima..."
    colima start
  else
    log "Colima already running"
  fi
fi

# ----------------------------
# Done
# ----------------------------
log "Bootstrap complete! (safe to re-run)"
echo ""
echo "Next steps:"
echo "  1) Add SSH key to GitHub → Settings → SSH & GPG keys"
echo "     (key is used for both auth and commit signing)"
echo "  2) Test: ssh -T git@github-personal"
echo "  3) Open Rectangle and Raycast once (macOS permissions)"
echo "  4) Restart terminal"
echo "  5) Per repo: run 'nvm install' / 'nvm use' when .nvmrc is present"
echo ""

if command -v pbcopy >/dev/null 2>&1; then
  cat "${KEY}.pub" | pbcopy
  log "SSH public key copied to clipboard"
fi
