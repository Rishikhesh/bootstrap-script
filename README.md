# bootstrap-script

One-command macOS setup: installs tools + apps, generates an SSH key, and
symlinks dotfiles with GNU Stow.

## New machine

```bash
git clone git@github-personal:Rishikhesh/bootstrap-script.git ~/personal/bootstrap-script
cd ~/personal/bootstrap-script
./bootstrap-mac.sh
```

Safe to re-run — every step is idempotent.

## What it installs

- **CLI**: git, openssh, nvm, bun, docker, colima, stow
- **Ricing**: eza, starship, zsh-autosuggestions, zsh-fast-syntax-highlighting
- **GUI**: arc, cursor, ghostty, raycast, rectangle, bruno, JetBrainsMono Nerd Font

## Dotfiles (Stow)

Each tool is its own Stow package under `dotfiles/`. Inside a package the tree
mirrors `$HOME`.

```
dotfiles/
  zsh/.zshrc                       -> ~/.zshrc
  ssh/.ssh/config                  -> ~/.ssh/config
  ghostty/.config/ghostty/config   -> ~/.config/ghostty/config
  starship/.config/starship.toml   -> ~/.config/starship.toml
```

The script links every package at once:

```bash
cd dotfiles && stow -t "$HOME" */
```

Adding a new tool = add a new folder (e.g. `dotfiles/git/.gitconfig`); it gets
picked up automatically. Link one on its own with `stow -t "$HOME" ghostty`.

Edit files in this repo (or the live symlinked paths — same file), then push:

```bash
dots   # alias: add -A, commit, push   (defined in .zshrc)
```

Re-link after adding files:

```bash
cd ~/personal/bootstrap-script/dotfiles && stow -R -t "$HOME" */
```

## Notes

- Secrets live in `~/.env.secrets` (gitignored, auto-created empty).
- SSH: script generates a single `id_ed25519` (auth + commit signing). Upload
  the printed public key to your GitHub account. All repos use
  `git@github-personal:...` remotes; that host falls back to `id_ed25519` when
  `id_ed25519_personal` is absent (fresh machine), so a single key is enough.
- After first run: add the printed SSH key to GitHub, open Rectangle + Raycast
  once for macOS permissions, restart the terminal.
