#!/usr/bin/env bash
#
# Reproduce this config on a fresh WSL Ubuntu install.
#
# Installs portable toolchain via apt, pulls neovim/lazygit/mise from
# vendor releases (since apt versions lag or are missing), and stows only the
# packages that make sense without a Wayland desktop.
#
# Usage:
#   cd ~/omarchy-dotfiles && ./install-wsl.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\n\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }

# --------------------------------------------------------------- platform guard
if ! grep -qi microsoft /proc/version 2>/dev/null; then
  echo "This script targets WSL. For native Arch/Omarchy, use ./install.sh" >&2
  exit 1
fi

# ------------------------------------------------------------------ apt packages
log "Installing apt packages"
sudo apt update
sudo apt install -y \
  build-essential ripgrep fd-find tmux stow git curl unzip wl-clipboard \
  python3-venv python3-pip \
  zsh fzf eza bat zoxide

mkdir -p "$HOME/.local/bin"

# ----------------------------------------------------------------------- neovim
if ! command -v nvim >/dev/null; then
  log "Installing neovim from GitHub release"
  tmp="$(mktemp -d)"
  curl -fsSLo "$tmp/nvim.tar.gz" \
    https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
  tar xzf "$tmp/nvim.tar.gz" -C "$tmp"
  rm -rf "$HOME/.local/share/nvim-bin"
  mv "$tmp/nvim-linux-x86_64" "$HOME/.local/share/nvim-bin"
  ln -sf "$HOME/.local/share/nvim-bin/bin/nvim" "$HOME/.local/bin/nvim"
  rm -rf "$tmp"
else
  log "neovim already installed ($(nvim --version | head -1))"
fi

# ---------------------------------------------------------------------- lazygit
if ! command -v lazygit >/dev/null; then
  log "Installing lazygit from GitHub release"
  version=$(curl -sf https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
    | grep -Po '"tag_name": *"v\K[^"]*')
  tmp="$(mktemp -d)"
  curl -fsSLo "$tmp/lazygit.tar.gz" \
    "https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_Linux_x86_64.tar.gz"
  tar xf "$tmp/lazygit.tar.gz" -C "$tmp" lazygit
  install -m 755 "$tmp/lazygit" "$HOME/.local/bin/lazygit"
  rm -rf "$tmp"
else
  log "lazygit already installed"
fi

# ------------------------------------------------------------------------- mise
if ! command -v mise >/dev/null && [ ! -x "$HOME/.local/bin/mise" ]; then
  log "Installing mise"
  curl -fsSL https://mise.run | sh
else
  log "mise already installed"
fi

# --------------------------------------------------------------------- starship
if ! command -v starship >/dev/null; then
  log "Installing starship"
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
else
  log "starship already installed"
fi

# ----------------------------------------------------------- oh-my-zsh + plugins
# Cloned directly instead of using the oh-my-zsh installer, which would
# overwrite ~/.zshrc (ours is stowed from zsh/).
clone_or_pull() { # <url> <dir>
  if [ -d "$2/.git" ]; then
    git -C "$2" pull -q --ff-only || warn "Couldn't update $2"
  else
    git clone -q --depth=1 "$1" "$2"
  fi
}
log "Installing oh-my-zsh and plugins"
clone_or_pull https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
ZSH_PLUGINS="$HOME/.oh-my-zsh/custom/plugins"
clone_or_pull https://github.com/zsh-users/zsh-autosuggestions.git     "$ZSH_PLUGINS/zsh-autosuggestions"
clone_or_pull https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_PLUGINS/zsh-syntax-highlighting"
clone_or_pull https://github.com/zsh-users/zsh-completions.git         "$ZSH_PLUGINS/zsh-completions"
clone_or_pull https://github.com/Aloxaf/fzf-tab.git                    "$ZSH_PLUGINS/fzf-tab"

# ------------------------------------------------------- fd symlink (fdfind -> fd)
if command -v fdfind >/dev/null && [ ! -e "$HOME/.local/bin/fd" ]; then
  ln -s "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi

# ------------------------------------------------------------------- stow subset
# Omit: bash (see note below), bin, hypr, waybar, kitty, ghostty, zen, systemd, system.
STOW_PACKAGES=(git lazygit mise nvim tmux xdg zsh starship)

log "Stowing dotfiles (${STOW_PACKAGES[*]})"
stow -v -R -t "$HOME" "${STOW_PACKAGES[@]}"

# --------------------------------------------------------- bashrc additions block
# We intentionally don't stow bash/ on WSL: Ubuntu's default .bashrc is richer
# than the Omarchy-centric one. Instead, append a small guarded block so
# mise activates in new shells.
MARK="# --- dotfiles additions ---"
if ! grep -qF "$MARK" "$HOME/.bashrc" 2>/dev/null; then
  log "Appending dotfiles block to ~/.bashrc"
  cat >> "$HOME/.bashrc" <<'EOF'

# --- dotfiles additions ---
command -v mise     >/dev/null && eval "$(mise activate bash)"
alias lg='lazygit'
EOF
else
  log "~/.bashrc already contains dotfiles additions block"
fi

# ---------------------------------------------------------- zsh as login shell
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v zsh)" ]; then
  log "Making zsh your default shell"
  sudo chsh -s "$(command -v zsh)" "$USER"
fi

# ------------------------------------------------------------- mise toolchains
if command -v mise >/dev/null; then
  log "Installing mise-managed toolchains"
  mise install || warn "mise install failed — run manually once you've opened a new shell"
fi

# --------------------------------------------------------- pre-sync nvim plugins
# So the first interactive nvim launch is instant instead of waiting for Lazy
# to clone ~70 plugins. Mason tools install on first nvim open after this.
if command -v nvim >/dev/null; then
  log "Syncing nvim plugins (headless)"
  nvim --headless "+Lazy! sync" +qa 2>&1 | tail -3 || \
    warn "Lazy sync failed — open nvim interactively to retry"
fi

# ------------------------------------------------------------------- summary
cat <<EOF

Done.

Next steps:
  * Open a new Windows Terminal tab (zsh is now your shell)
  * Machine-only env vars/secrets go in ~/.zshrc.local (not in the repo)
  * Launch nvim            (Mason will install LSP/formatters on first open)
  * Inside nvim:           :checkhealth    (confirm providers / treesitter)
EOF
