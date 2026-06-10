#!/bin/bash
set -eu

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

PREFERRED_SHELL="${PREFERRED_SHELL:-bash}"

if [ "$PREFERRED_SHELL" = "zsh" ]; then
  # --- Install zsh plugins (idempotent) ---
  mkdir -p "$HOME/.zsh"
  [ ! -d "$HOME/.zsh/zsh-autosuggestions" ] && \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
  [ ! -d "$HOME/.zsh/zsh-syntax-highlighting" ] && \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting ~/.zsh/zsh-syntax-highlighting

  # --- Symlink shared config ---
  mkdir -p ~/.config
  ln -sf "$DOTFILES_DIR/.config/starship.toml" ~/.config/starship.toml

  # --- Write ~/.zshrc (idempotent guard) ---
  if ! grep -q 'AQEMIA_DOTFILES' ~/.zshrc 2>/dev/null; then
    cat >> ~/.zshrc <<ZSHRC

# AQEMIA_DOTFILES
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Starship + zoxide
command -v starship &>/dev/null && eval "\$(starship init zsh)"
command -v zoxide &>/dev/null && eval "\$(zoxide init --cmd cd zsh)"

# History
export HISTFILE="\$HOME/.zsh_history"
export HISTSIZE=2000000
export SAVEHIST=2000000
setopt HIST_IGNORE_ALL_DUPS SHARE_HISTORY

export EDITOR=vim
export KUBE_EDITOR=vim

# Go / Cargo / Krew
GOPATH=\${HOME}/go
export PATH=\$PATH:\$GOPATH/bin:\$HOME/.cargo/bin:\${KREW_ROOT:-\$HOME/.krew}/bin

# Aliases
source "$DOTFILES_DIR/aliases/custom.bash"

# Terraform cache
export TF_PLUGIN_CACHE_DIR=\$HOME/.terraform.d/plugin-cache
export TG_PROVIDER_CACHE=true

# Auto-attach to a stable zellij session so layout/panes resurrect across
# coder workspace restarts. Skip when already inside zellij (\$ZELLIJ is set
# to "0" in inner panes), in non-interactive shells, or in VS Code's
# integrated terminal.
#
# No \`exec\`: keep a real shell behind zellij so detaching (Ctrl+o d) or
# quitting returns to a prompt instead of closing the coder terminal.
if [ -z "\$ZELLIJ" ] && [ -t 1 ] && [ "\$TERM_PROGRAM" != "vscode" ] && command -v zellij >/dev/null; then
  zellij attach --create main
fi
ZSHRC
  fi

  # chsh fails in containers (PAM requires a password). Fall back to exec-ing zsh
  # from ~/.bash_profile so any bash login shell (coder ssh, web terminal) switches
  # to zsh automatically.
  ZSH_PATH=$(command -v zsh)
  chsh -s "$ZSH_PATH" || true

  # Break symlink if present (may exist when switching from bash), then append exec
  [ -L ~/.bash_profile ] && cp -L ~/.bash_profile ~/.bash_profile.tmp && mv ~/.bash_profile.tmp ~/.bash_profile 2>/dev/null || true
  if ! grep -q 'AQEMIA_SHELL_SWITCH' ~/.bash_profile 2>/dev/null; then
    cat >> ~/.bash_profile <<PROFILE

# AQEMIA_SHELL_SWITCH - exec into zsh when chsh is unavailable (container environments)
[ -n "\$PS1" ] && exec "$ZSH_PATH" -l
PROFILE
  fi

else
  # --- Install bash-it ---
  if [ ! -d "$HOME/.bash_it" ]; then
      echo "Installing bash-it..."
      git clone --depth=1 https://github.com/Bash-it/bash-it.git "$HOME/.bash_it"
  fi

  # --- Enable bash-it components via symlinks ---
  mkdir -p "$HOME/.bash_it/enabled"

  # Aliases
  for a in bash-it directory editor general; do
      ln -sf "$HOME/.bash_it/aliases/available/${a}.aliases.bash" \
             "$HOME/.bash_it/enabled/150---${a}.aliases.bash" 2>/dev/null || true
  done

  # Plugins
  ln -sf "$HOME/.bash_it/plugins/available/base.plugin.bash" \
         "$HOME/.bash_it/enabled/250---base.plugin.bash"

  # Completions
  for c in system bash-it docker git github-cli go kubectl terraform; do
      ln -sf "$HOME/.bash_it/completion/available/${c}.completion.bash" \
             "$HOME/.bash_it/enabled/350---${c}.completion.bash" 2>/dev/null || true
  done
  ln -sf "$HOME/.bash_it/completion/available/system.completion.bash" \
         "$HOME/.bash_it/enabled/325---system.completion.bash"
  ln -sf "$HOME/.bash_it/completion/available/aliases.completion.bash" \
         "$HOME/.bash_it/enabled/800---aliases.completion.bash"

  # --- Symlink config files ---
  mkdir -p ~/.config ~/.bash_it/custom ~/.bash_it/aliases

  ln -sf "$DOTFILES_DIR/.config/starship.toml" ~/.config/starship.toml
  ln -sf "$DOTFILES_DIR/custom/custom.bash" ~/.bash_it/custom/custom.bash
  ln -sf "$DOTFILES_DIR/aliases/custom.bash" ~/.bash_it/aliases/custom.bash

  # --- Ensure .bash_profile sources .bashrc (login shells) ---
  # Remove any zsh exec switch before symlinking (handles zsh→bash switch)
  if [ -f ~/.bash_profile ] && ! [ -L ~/.bash_profile ]; then
    sed -i '/# AQEMIA_SHELL_SWITCH/,+2d' ~/.bash_profile 2>/dev/null || true
  fi
  ln -sf "$DOTFILES_DIR/.bash_profile" ~/.bash_profile

  # --- Ensure .bashrc loads bash-it ---
  if ! grep -q 'BASH_IT' ~/.bashrc 2>/dev/null; then
      cat >> ~/.bashrc <<'BASHRC'

# bash-it
export BASH_IT="$HOME/.bash_it"
export BASH_IT_THEME='pure'
export SCM_CHECK=true
unset MAILCHECK
source "$BASH_IT/bash_it.sh"
BASHRC
  fi

fi

# --- Install tools via mise ---
if command -v mise &>/dev/null; then
  echo "Installing mise tools..."
  mise use --global neovim@stable zellij@latest fzf@latest fd@latest lazygit@latest delta@latest bat@latest eza@latest jq@latest
fi

# --- LazyVim setup ---
if [ ! -f "$HOME/.config/nvim/lazyvim.json" ]; then
  echo "Installing LazyVim..."
  # Back up any existing nvim config
  [ -d "$HOME/.config/nvim" ] && mv "$HOME/.config/nvim" "$HOME/.config/nvim.bak.$(date +%s)"
  git clone --depth=1 https://github.com/LazyVim/starter "$HOME/.config/nvim"
  # Remove .git so the user can track their own changes
  rm -rf "$HOME/.config/nvim/.git"
fi

# --- Symlink personal nvim overrides if present ---
if [ -d "$DOTFILES_DIR/.config/nvim" ]; then
  # Overlay dotfiles nvim config on top of LazyVim starter
  cp -r "$DOTFILES_DIR/.config/nvim/." "$HOME/.config/nvim/"
fi

# --- Zellij config ---
if [ -d "$DOTFILES_DIR/.config/zellij" ]; then
  mkdir -p "$HOME/.config/zellij/layouts"
  ln -sf "$DOTFILES_DIR/.config/zellij/config.kdl" "$HOME/.config/zellij/config.kdl" 2>/dev/null || true
  # default.kdl is the layout zellij applies to every new session; it sets the
  # zellaude top bar (Claude Code activity awareness). Requires jq at runtime.
  ln -sf "$DOTFILES_DIR/.config/zellij/layouts/default.kdl" "$HOME/.config/zellij/layouts/default.kdl" 2>/dev/null || true
fi

# --- Install / update Claude Code CLI ---
echo "Installing latest Claude Code CLI..."
curl -fsSL https://claude.ai/install.sh | bash

echo "Dotfiles installed successfully."
