# windows-dotfiles

Config for the Windows machine: WSL Ubuntu (Neovim/LazyVim, tmux, etc.)
plus the native Windows side (WezTerm, kanata).

Sibling repo: [omarchy-dotfiles](https://github.com/SlipsKnuten/omarchy-dotfiles)
for the Arch/Omarchy machine.

## Layout

```
git/   tmux/   lazygit/   mise/   nvim/   xdg/
\______ stowed into $HOME on WSL ______/

windows/    .wezterm.lua + kanata.kbd + setup-windows.ps1
            — the script copies them into %USERPROFILE% and installs kanata

install-wsl.sh    Bootstrap a fresh WSL Ubuntu install
```

## WSL setup (fresh install)

Inside WSL Ubuntu, on a clean install:

```bash
git clone https://github.com/SlipsKnuten/windows-dotfiles.git ~/windows-dotfiles
cd ~/windows-dotfiles && ./install-wsl.sh
```

No auth needed — the repo is public, HTTPS clone works out of the box.

The script:
- Installs the apt baseline (build-essential, ripgrep, fd-find, tmux, stow, …).
- Pulls neovim, lazygit, mise from vendor releases (apt versions lag).
- Stows the Linux configs into `~/.config`.
- Appends a guarded mise activation block to `~/.bashrc`.
- Pre-syncs LazyVim plugins headlessly so the first `nvim` launch is instant.

After it finishes: open a new shell, then `nvim` — Mason will install
LSPs/formatters on first open. Run `:checkhealth` to verify.

If you want to push back to this repo, set up auth once:
- HTTPS: `sudo apt install gh && gh auth login`, or
- SSH: `ssh-keygen -t ed25519 -C "your@email"` then add the pubkey at
  https://github.com/settings/ssh/new and switch the remote to
  `git@github.com:SlipsKnuten/windows-dotfiles.git`.

## Windows setup

From inside WSL, after cloning this repo:

```bash
powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w ~/windows-dotfiles/windows/setup-windows.ps1)"
```

`windows/setup-windows.ps1`:
- Copies `.wezterm.lua` to `%USERPROFILE%` and `kanata.kbd` to `%USERPROFILE%\.config\kanata\`.
- Downloads kanata (pinned to `$KanataVersion` at the top of the script),
  verifies its checksum, and installs it as `%USERPROFILE%\bin\kanata.exe`.
- Checks the config, adds a Startup shortcut so kanata runs on login, and
  (re)starts it.

It's safe to run again, for example after a `git pull` that changed
`kanata.kbd`. It only downloads kanata again when the version changes.

### Home row mods (kanata)

`kanata.kbd` puts Alt and Shift on the home row: hold `a` for Alt and hold
`s` for Shift, and tap them to type the letter as usual (capital `J` = hold
`s`, press `j`). The examples are in the comment at the top of the file.

- Emergency exit: physical Left Ctrl + Space + Esc.
- Windows won't let kanata affect apps running as Administrator unless kanata
  itself runs as admin.
- If letters turn into Alt/Shift while typing fast, raise `hold-time` in
  `kanata.kbd`, then run the setup script again.
