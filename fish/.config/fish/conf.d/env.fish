set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx LANG en_US.UTF-8

# Ollama default context window. This is the num_ctx for requests that do NOT set it
# themselves — i.e. the AGENTIC path (pi) and `ollama run`. The non-agentic HTTP
# provider (_ai_provider_ollama) overrides num_ctx per-request, so this does not cap it.
# 131072 lets agentic-local reviews of big commits fit (a ~37k-token prompt + the
# model's file reads); measured KV cost keeps north-mini/laguna well under 36GB RAM.
# Raising this trades KV-cache RAM for headroom; models still cap at their native max.
set -gx OLLAMA_CONTEXT_LENGTH 131072

test -f ~/.config/fish/conf.d/env.local.fish; and source ~/.config/fish/conf.d/env.local.fish
