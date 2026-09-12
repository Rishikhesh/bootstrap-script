#!/usr/bin/env bash
set -euo pipefail

log()  { printf "\n\033[1;32m%s\033[0m\n" "$*"; }
warn() { printf "\n\033[1;33m%s\033[0m\n" "$*"; }

[[ "$(uname -s)" == "Darwin" ]] || { echo "macOS only"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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
# Packages (declarative Brewfile)
# ----------------------------
# Edit ./Brewfile to add/remove tools. brew bundle is idempotent —
# installs what's missing, no-op for what's present.
log "Syncing Brewfile..."
brew bundle --file="$SCRIPT_DIR/Brewfile"
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
  if nvm ls --no-colors 'lts/*' >/dev/null 2>&1; then
    log "Node LTS already installed via nvm"
  else
    nvm install --lts >/dev/null
  fi

  # Don't clobber an existing default alias.
  CURRENT_DEFAULT="$(nvm alias default --no-colors 2>/dev/null | head -1 || true)"
  if [[ -n "$CURRENT_DEFAULT" ]]; then
    log "nvm default alias already set: $CURRENT_DEFAULT (keeping)"
  else
    nvm alias default 'lts/*' >/dev/null
    log "nvm default alias = lts/*"
  fi
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
KEY_IS_NEW=0

if [[ ! -f "$KEY" ]]; then
  read -r -p "Email for SSH key: " SSH_EMAIL
  ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f "$KEY"
  KEY_IS_NEW=1
else
  log "SSH key already exists: $KEY (not regenerated)"
fi

# Reuse the running agent if there is one; only spawn a new one otherwise.
if [[ -z "${SSH_AUTH_SOCK:-}" ]] || ! ssh-add -l >/dev/null 2>&1; then
  eval "$(ssh-agent -s)" >/dev/null
fi

if ssh-add -l 2>/dev/null | grep -q "$(ssh-keygen -lf "$KEY.pub" | awk '{print $2}')"; then
  log "SSH key already loaded in agent"
else
  ssh-add --apple-use-keychain "$KEY" 2>/dev/null || ssh-add "$KEY" || true
fi

# ----------------------------
# Symlink dotfiles (Stow)
# ----------------------------
log "Linking dotfiles with Stow..."
[[ -e "$HOME/.env.secrets" ]] || touch "$HOME/.env.secrets"

# Let Stow itself report conflicts (dry-run), then back up ONLY the real files
# it names. Never walk the tree by hand: a target path can be a symlink into
# this repo, and testing/moving through it would rename files inside the repo.
STAMP="$(date +%Y%m%d%H%M%S)"
PACKAGES_DIR="$SCRIPT_DIR/dotfiles"
STOW_PKGS=()
for d in "$PACKAGES_DIR"/*/; do STOW_PKGS+=("$(basename "$d")"); done

# Stow names each blocking file relative to $HOME. Across stow versions the
# phrasing differs, so match both known forms:
#   "cannot stow SRC over existing target <path> since neither a link nor a directory ..."
#   "existing target is neither a link nor a directory: <path>"
conflicts="$(cd "$PACKAGES_DIR" && stow -n -v --restow -t "$HOME" "${STOW_PKGS[@]}" 2>&1 \
  | sed -n \
      -e 's/.*over existing target \(.*\) since neither a link nor a directory.*/\1/p' \
      -e 's/.*existing target is neither a link nor a directory: \(.*\)/\1/p')"

if [[ -n "$conflicts" ]]; then
  while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    target="$HOME/$rel"
    backup="${target}.backup.${STAMP}"
    warn "Backing up $target -> $backup"
    mv "$target" "$backup"
  done <<< "$conflicts"
fi

# Link every package folder under dotfiles/ (zsh, ssh, ghostty, starship, ...).
# Add a new tool = add a new folder; no script edit needed.
# --restow cleans stale links first so re-runs converge instead of erroring.
# The `git` module uses --no-folding so ~/.config/git stays a real directory,
# leaving room for the machine-local work.local beside the linked config.
for pkg in "${STOW_PKGS[@]}"; do
  flags=(--restow)
  [[ "$pkg" == "git" ]] && flags+=(--no-folding)
  ( cd "$PACKAGES_DIR" && stow "${flags[@]}" -t "$HOME" "$pkg" )
done
[[ -e "$HOME/.ssh/config" ]] && chmod 600 "$HOME/.ssh/config"
log "Dotfiles linked"

# ----------------------------
# Git config
# ----------------------------
# Personal identity lives in the tracked, stowed file ~/.config/git/config.
# Nothing is written with `git config --global` anymore, so re-runs never
# clobber your settings. Two housekeeping steps:

# 1) Retire any legacy ~/.gitconfig — it has HIGHER precedence than the XDG
#    file and would silently shadow the stowed config. Back it up once.
if [[ -f "$HOME/.gitconfig" && ! -L "$HOME/.gitconfig" ]]; then
  backup="$HOME/.gitconfig.backup.$(date +%Y%m%d%H%M%S)"
  warn "Legacy ~/.gitconfig found — backing up to $backup (stowed config takes over)"
  mv "$HOME/.gitconfig" "$backup"
fi

# 2) Seed a machine-local work identity template (untracked). Repos under
#    ~/work/ use it via the includeIf in the stowed config. Never overwritten.
WORK_LOCAL="$HOME/.config/git/work.local"
if [[ ! -e "$WORK_LOCAL" ]]; then
  log "Seeding work identity template at $WORK_LOCAL (edit with your work details)"
  cat > "$WORK_LOCAL" <<'EOF'
# Machine-local work identity — NOT tracked in the dotfiles repo.
# Applies to any repo under ~/work/ (see includeIf in ~/.config/git/config).
[user]
	name = rishikhesh
	email = dev@cypherd.io
	# signingkey = ~/.ssh/id_ed25519_work.pub
EOF
fi
log "Git config linked (personal) + work.local ready"

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

# Only hijack the clipboard when the key was just created.
if [[ "$KEY_IS_NEW" == "1" ]] && command -v pbcopy >/dev/null 2>&1; then
  pbcopy < "${KEY}.pub"
  log "SSH public key copied to clipboard"
fi
