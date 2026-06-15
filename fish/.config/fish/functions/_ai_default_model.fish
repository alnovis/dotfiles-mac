function _ai_default_model --description "Resolve model: per-task config > AI_DEFAULT_MODEL > hardcoded (ollama only)"
    set -l task $argv[1]
    set -l provider $argv[2]

    # 1. Per-task model (works for any provider — caller is responsible for compat)
    if test -n "$task"
        set -l v (_ai_config_read "$task"_model)
        if test $status -eq 0; and test -n "$v"
            echo $v
            return
        end
    end

    # 2. Global env var — treated as ollama-targeted (won't apply to non-ollama providers)
    if set -q AI_DEFAULT_MODEL; and test -n "$AI_DEFAULT_MODEL"
        if test -z "$provider"; or test "$provider" = ollama
            echo $AI_DEFAULT_MODEL
            return
        end
    end

    # 3. Hardcoded ollama fallback; silent for non-ollama providers
    if test -z "$provider"; or test "$provider" = ollama
        echo qwen3.5:9b
    end
end
