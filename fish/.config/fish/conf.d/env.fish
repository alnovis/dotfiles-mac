set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx LANG en_US.UTF-8

# Ollama context window (model arch limits apply; 32K is safe for all installed models)
set -gx OLLAMA_CONTEXT_LENGTH 32768

test -f ~/.config/fish/conf.d/env.local.fish; and source ~/.config/fish/conf.d/env.local.fish
