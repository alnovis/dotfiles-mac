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
    cp .gitignore_global ~/.gitignore_global
    git config --global core.excludesfile ~/.gitignore_global

    # Oh My Fish + bobthefish theme
    if command -v fish >/dev/null 2>&1; then
      if [ ! -d "$HOME/.local/share/omf" ]; then
        echo "Installing Oh My Fish..."
        curl -sL https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install | fish --command 'source - --noninteractive'
      fi
      fish -c 'omf install bobthefish' 2>/dev/null || true
    fi

    echo "Done! Restart terminal."
    ;;
  brew)
    cd "$(dirname "$0")"
    brew bundle --file=Brewfile
    ;;
  unstow)
    cd "$(dirname "$0")"
    stow -D nvim kitty fish
    echo "Symlinks removed."
    ;;
esac