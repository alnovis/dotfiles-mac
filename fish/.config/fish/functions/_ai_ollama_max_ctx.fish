function _ai_ollama_max_ctx --description "RAM-safe ceiling for num_ctx: AI_OLLAMA_MAX_CTX > config key ollama_max_ctx > 131072"
    # 131072 fits this machine's 36 GB with the models in use (KV cost measured, see env.fish
    # on OLLAMA_CONTEXT_LENGTH). A machine with less RAM sets ollama_max_ctx in its config.
    set -l default_ceiling 131072
    if set -q AI_OLLAMA_MAX_CTX; and test -n "$AI_OLLAMA_MAX_CTX"
        echo $AI_OLLAMA_MAX_CTX
        return
    end
    set -l v (_ai_config_read ollama_max_ctx)
    if test -n "$v"
        echo $v
    else
        echo $default_ceiling
    end
end
