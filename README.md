# windows-dotfiles

Config for the Windows machine: WSL Ubuntu (Neovim/LazyVim, tmux, starship, etc.)
plus the native Windows side (WezTerm, starship).

Sibling repo: [omarchy-dotfiles](https://github.com/SlipsKnuten/omarchy-dotfiles)
for the Arch/Omarchy machine.

## Layout

```
git/        starship/      tmux/         lazygit/   mise/   nvim/   xdg/
            \____________ stowed into $HOME on WSL ____________/

windows/    .wezterm.lua + .config/starship.toml — copied to %USERPROFILE% on Windows

install-wsl.sh    Bootstrap a fresh WSL Ubuntu install
```

## WSL setup (fresh install)

```bash
git clone git@github.com:SlipsKnuten/windows-dotfiles.git ~/windows-dotfiles
cd ~/windows-dotfiles
./install-wsl.sh
```

The script installs the apt baseline, pulls neovim/lazygit/starship/mise from
vendor releases (apt versions lag), stows the Linux configs, and appends a
guarded starship/mise activation block to `~/.bashrc`.

## Windows setup

Copy the two files in `windows/` to your Windows user profile:

```powershell
# From PowerShell on the Windows side
$repo = "\\wsl$\Ubuntu-24.04\home\gud\windows-dotfiles\windows"
Copy-Item "$repo\.wezterm.lua" $HOME\.wezterm.lua
New-Item -ItemType Directory -Force $HOME\.config | Out-Null
Copy-Item "$repo\.config\starship.toml" $HOME\.config\starship.toml
```

Then ensure `starship` is on PATH and your PowerShell profile contains:

```powershell
Invoke-Expression (&starship init powershell)
```
