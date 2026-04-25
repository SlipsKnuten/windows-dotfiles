#!/usr/bin/env bash
#
# Reproduce this config on a fresh WSL Ubuntu install.
#
# Installs portable toolchain via apt, pulls neovim/lazygit/starship/mise from
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
  build-essential ripgrep fd-find tmux stow git curl unzip \
  python3-venv python3-pip

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

# --------------------------------------------------------------------- starship
if ! command -v starship >/dev/null; then
  log "Installing starship"
  curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
else
  log "starship already installed"
fi

# ------------------------------------------------------------------------- mise
if ! command -v mise >/dev/null && [ ! -x "$HOME/.local/bin/mise" ]; then
  log "Installing mise"
  curl -fsSL https://mise.run | sh
else
  log "mise already installed"
fi

# ------------------------------------------------------- fd symlink (fdfind -> fd)
if command -v fdfind >/dev/null && [ ! -e "$HOME/.local/bin/fd" ]; then
  ln -s "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi

# ------------------------------------------------------------------- stow subset
# Omit: bash (see note below), bin, hypr, waybar, kitty, ghostty, zen, systemd, system.
STOW_PACKAGES=(git lazygit mise nvim starship tmux xdg)

log "Stowing dotfiles (${STOW_PACKAGES[*]})"
stow -v -R -t "$HOME" "${STOW_PACKAGES[@]}"

# --------------------------------------------------------- bashrc additions block
# We intentionally don't stow bash/ on WSL: Ubuntu's default .bashrc is richer
# than the Omarchy-centric one. Instead, append a small guarded block so
# starship/mise activate in new shells.
MARK="# --- dotfiles additions ---"
if ! grep -qF "$MARK" "$HOME/.bashrc" 2>/dev/null; then
  log "Appending dotfiles block to ~/.bashrc"
  cat >> "$HOME/.bashrc" <<'EOF'

# --- dotfiles additions ---
command -v starship >/dev/null && eval "$(starship init bash)"
command -v mise     >/dev/null && eval "$(mise activate bash)"
alias lg='lazygit'
EOF
else
  log "~/.bashrc already contains dotfiles additions block"
fi

# ------------------------------------------------------------- mise toolchains
if command -v mise >/dev/null; then
  log "Installing mise-managed toolchains"
  mise install || warn "mise install failed — run manually once you've opened a new shell"
fi

# ------------------------------------------------------------------- summary
cat <<EOF

Done.

Next steps:
  * Open a new shell, or:  source ~/.bashrc
  * Launch nvim            (LazyVim will sync plugins on first run)
  * Inside nvim:           :checkhealth    (confirm providers / treesitter)
EOF
