set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx LANG en_US.UTF-8

test -f ~/.config/fish/conf.d/env.local.fish; and source ~/.config/fish/conf.d/env.local.fish
