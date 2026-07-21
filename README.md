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

At the start it lists all packages (all selected by default); enter the numbers
you want to **skip** (space-separated), or just press Enter to install everything.

## What it installs

- **CLI**: git, openssh, nvm, bun, docker, colima, stow, zoxide, fzf, bat, fd
- **Ricing**: eza, fastfetch, starship, zsh-autosuggestions, zsh-fast-syntax-highlighting
- **GUI**: arc, cursor, ghostty, raycast, rectangle, bruno, JetBrainsMono Nerd Font

## Dotfiles (Stow)

Each tool is its own Stow package under `dotfiles/`. Inside a package the tree
mirrors `$HOME`.

```
dotfiles/
  zsh/.zshrc                       -> ~/.zshrc
  ssh/.ssh/config                  -> ~/.ssh/config
  ghostty/.config/ghostty/config   -> ~/.config/ghostty/config
  bat/.config/bat/config           -> ~/.config/bat/config
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

## Developer shell shortcuts

- `z <name>` jumps to a frequently used directory; `zi` opens an interactive picker.
- `Ctrl-R` searches command history, `Ctrl-T` inserts a file, and `Alt-C` changes directory.
- `cat` uses Bat with syntax highlighting; use `command cat` when raw system output is needed.
- `ll` is a Git-aware detailed Eza view, `lt` is a `.gitignore`-aware tree, and `lc`
  summarizes repository languages and lines of code.
- `lr` lists recently modified entries first; `ld` lists directories only.

## Notes

- Secrets live in `~/.env.secrets` (gitignored, auto-created empty).
- SSH: script generates a single `id_ed25519` (auth + commit signing). Upload
  the printed public key to your GitHub account. All repos use
  `git@github-personal:...` remotes; that host falls back to `id_ed25519` when
  `id_ed25519_personal` is absent (fresh machine), so a single key is enough.
- After first run: add the printed SSH key to GitHub, open Rectangle + Raycast
  once for macOS permissions, restart the terminal.
