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

  BREW_BIN=""
  [[ -x /opt/homebrew/bin/brew ]] && BREW_BIN=/opt/homebrew/bin/brew
  [[ -x /usr/local/bin/brew ]] && BREW_BIN=/usr/local/bin/brew
  if [[ -n "$BREW_BIN" ]]; then
    eval "$("$BREW_BIN" shellenv)"
    grep -q 'brew shellenv' ~/.zprofile 2>/dev/null || \
      echo "eval \"\$($BREW_BIN shellenv)\"" >> ~/.zprofile
  fi
else
  log "Homebrew already installed"
fi

brew update

# ----------------------------
# Package selection
# ----------------------------
# type:name — CLI formulae first, then GUI casks.
PACKAGES=(
  "formula:git"        "formula:openssh"   "formula:nvm"       "formula:bun"
  "formula:docker"     "formula:colima"    "formula:stow"      "formula:eza"
  "formula:starship"   "formula:zsh-autosuggestions"
  "formula:zsh-fast-syntax-highlighting"  "formula:fastfetch"
  "cask:arc"           "cask:cursor"       "cask:ghostty"      "cask:raycast"
  "cask:rectangle"     "cask:bruno"        "cask:font-jetbrains-mono-nerd-font"
)

# bash 3.2 (default macOS) has no associative arrays — track skips as a padded string.
SKIP_LIST=" "
if [[ -t 0 ]]; then
  log "Packages to install (default: ALL):"
  i=1
  for it in "${PACKAGES[@]}"; do
    printf "  %2d) [%s] %s\n" "$i" "${it%%:*}" "${it#*:}"
    i=$((i + 1))
  done
  printf "\nEnter numbers to SKIP (space-separated), or press Enter to install everything: "
  read -r skip_nums || skip_nums=""
  for n in $skip_nums; do
    [[ "$n" =~ ^[0-9]+$ ]] && SKIP_LIST+="$n "
  done
else
  warn "Non-interactive shell — installing all packages."
fi

log "Installing packages..."
i=1
for it in "${PACKAGES[@]}"; do
  name="${it#*:}"; kind="${it%%:*}"
  if [[ "$SKIP_LIST" == *" $i "* ]]; then
    warn "  skip: $name"
  elif [[ "$kind" == "formula" ]]; then
    brew_install "$name"
  else
    brew_cask_install "$name"
  fi
  i=$((i + 1))
done

brew cleanup || true

# ----------------------------
# NVM + Node LTS
# ----------------------------
log "Configuring NVM..."
mkdir -p ~/.nvm
export NVM_DIR="$HOME/.nvm"

NVM_SH="$(brew --prefix nvm 2>/dev/null)/nvm.sh"
[[ -s "$NVM_SH" ]] && . "$NVM_SH"

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

KEY="$HOME/.ssh/id_ed25519"

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
for f in .zshrc .ssh/config .config/ghostty/config .config/starship.toml; do
  target="$HOME/$f"
  if [[ -e "$target" && ! -L "$target" ]]; then
    backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
    warn "Backing up $target → $backup"
    mv "$target" "$backup"
  fi
done

# Link every package folder under dotfiles/ (zsh, ssh, ghostty, starship, ...).
# Add a new tool = add a new folder; no script edit needed.
( cd "$SCRIPT_DIR/dotfiles" && stow -t "$HOME" */ )
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
