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
# The KV cache is allocated for the whole window, whatever a request uses: granite4.2:8b
# (5 GB of weights) took 27 GB at 131072, the machine went to swap, and two runs hung with
# the runner stuck in "Stopping…". An 8-bit cache is half the size at near the same
# quality; it needs flash attention. Read when the server starts: `ai stop` after a change.
set -gx OLLAMA_FLASH_ATTENTION 1
set -gx OLLAMA_KV_CACHE_TYPE q8_0

test -f ~/.config/fish/conf.d/env.local.fish; and source ~/.config/fish/conf.d/env.local.fish
