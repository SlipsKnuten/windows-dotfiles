# ~/.zshrc — stowed from windows-dotfiles/zsh. Machine-specific stuff
# (secrets, work env vars) goes in ~/.zshrc.local, which isn't in the repo.

# ------------------------------------------------------------------------ PATH
typeset -U path # drop duplicates
path=("$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/.npm-global/bin" $path)

export EDITOR=nvim
export VISUAL=nvim

# ------------------------------------------------------------------- oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_CUSTOM="$ZSH/custom"
ZSH_THEME="" # starship draws the prompt
zstyle ':omz:update' mode reminder

# Extra completion definitions (docker, cargo, …). Must be on fpath before
# oh-my-zsh runs compinit.
fpath+=("$ZSH_CUSTOM/plugins/zsh-completions/src")

# fzf-tab has to come after compinit (oh-my-zsh handles that) and before
# the two plugins that wrap widgets. zsh-syntax-highlighting must be last.
plugins=(
  git
  sudo               # Esc Esc puts sudo in front of the current command
  extract            # `extract file.tar.gz` for any archive type
  colored-man-pages
  command-not-found
  fzf-tab
  zsh-autosuggestions
  zsh-syntax-highlighting
)

ZSH_AUTOSUGGEST_STRATEGY=(history completion)

source "$ZSH/oh-my-zsh.sh"

# --------------------------------------------------------------------- history
HISTSIZE=100000
SAVEHIST=100000
setopt HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS SHARE_HISTORY

# ------------------------------------------------------------------ completion
# fzf-tab replaces the completion menu with fzf.
zstyle ':completion:*:*:*:*:*' menu no # same pattern oh-my-zsh uses, so this wins
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:*' use-fzf-default-opts yes
zstyle ':fzf-tab:complete:(cd|z|ls|eza):*' fzf-preview \
  'eza -1 --color=always --icons --group-directories-first $realpath 2>/dev/null || ls -1 $realpath'

# ------------------------------------------------------------------------- fzf
# Ctrl-R history search, Ctrl-T file picker, Alt-C cd into a folder.
if fzf --zsh >/dev/null 2>&1; then
  source <(fzf --zsh)
elif [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then
  source /usr/share/doc/fzf/examples/key-bindings.zsh # older apt fzf
fi
if command -v fd >/dev/null; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
fi
# Catppuccin Mocha
export FZF_DEFAULT_OPTS="--height=50% --layout=reverse --border=rounded \
--color=bg+:#313244,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,header:#f38ba8 \
--color=info:#cba6f7,pointer:#f5e0dc,marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7 \
--color=hl+:#f38ba8,selected-bg:#45475a,border:#585b70"

# ----------------------------------------------------------------------- tools
command -v mise   >/dev/null && eval "$(mise activate zsh)"
command -v zoxide >/dev/null && eval "$(zoxide init zsh)" # `z foo` jumps to a recent dir
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

if command -v eza >/dev/null; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -lah --icons --git --group-directories-first'
  alias lt='eza --tree --level=2 --icons --group-directories-first'
else
  alias ll='ls -lah'
fi

# Ubuntu's apt package calls it batcat.
command -v bat >/dev/null || { command -v batcat >/dev/null && alias bat='batcat'; }
export BAT_THEME=ansi # follow the terminal's colors

alias lg='lazygit'
alias v='nvim'

# ------------------------------------------------------------ Windows Terminal
# Tell Windows Terminal the current folder, so "duplicate pane/tab" opens in
# the same place instead of ~.
if [[ -n "$WT_SESSION" ]] && command -v wslpath >/dev/null; then
  _wt_report_cwd() { printf '\e]9;9;%s\e\\' "$(wslpath -w "$PWD")"; }
  chpwd_functions+=(_wt_report_cwd)
  _wt_report_cwd
fi

# ---------------------------------------------------------------------- prompt
command -v starship >/dev/null && eval "$(starship init zsh)"

[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
