#!/bin/bash
set -e

case "${1:-install}" in
  install)
    cd "$(dirname "$0")"
    if command -v brew >/dev/null 2>&1; then
      brew bundle --file=Brewfile
    else
      echo "Warning: brew not found, skipping Brewfile. Install Homebrew first: https://brew.sh"
    fi
    stow -v nvim kitty fish
    # agents: opencode runner profiles for the ai toolkit. Create the target dir first so
    # stow links each file instead of folding the whole dir into the repo.
    mkdir -p ~/.config/opencode/agents
    stow -v agents
    cp .gitignore_global ~/.gitignore_global
    git config --global core.excludesfile ~/.gitignore_global

    # Fish plugins via fisher (bobthefish theme, sdkman-for-fish): list in fish/.config/fish/fish_plugins
    if command -v fish >/dev/null 2>&1; then
      echo "Installing fish plugins..."
      fish -c 'type -q fisher; or curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source; fisher update' \
        || echo "Warning: fisher update failed, run 'fisher update' manually"
    fi

    echo "Done! Restart terminal."
    ;;
  brew)
    cd "$(dirname "$0")"
    brew bundle --file=Brewfile
    ;;
  unstow)
    cd "$(dirname "$0")"
    stow -D nvim kitty fish agents
    echo "Symlinks removed."
    ;;
esac