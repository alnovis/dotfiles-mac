#!/bin/bash
set -e

case "${1:-install}" in
  install)
    cd "$(dirname "$0")"
    stow -v nvim kitty fish
    cp .gitignore_global ~/.gitignore_global
    git config --global core.excludesfile ~/.gitignore_global
    echo "Done! Restart terminal."
    ;;
  unstow)
    cd "$(dirname "$0")"
    stow -D nvim kitty fish
    echo "Symlinks removed."
    ;;
esac