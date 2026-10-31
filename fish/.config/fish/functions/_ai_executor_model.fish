function _ai_executor_model --description "Model for DISPATCH serving PROVIDER: MODEL if given, else the executor's default; fails if a runner gets none" --argument-names dispatch provider model
    # The native driver and claude resolve their own default (empty is fine for them).
    # A runner needs a model: the default ollama model for ollama, otherwise the first model
    # the runner lists for the provider (that list is the runner's own config).
    if test -n "$model"; or test "$dispatch" = _ai_provider_ollama; or test "$provider" = claude
        echo $model
        return 0
    end
    if test "$provider" = ollama
        set model (_ai_default_model "" ollama)
        if test -z "$model"
            echo "ollama: no model configured — set one with: ai models use MODEL" >&2
            return 1
        end
        echo $model
        return 0
    end
    set -l runner (string replace _ai_agent_ '' -- $dispatch)
    _ai_agent_{$runner}_models | string match -r -g (printf '^%s\t(.+)$' (string escape --style=regex -- $provider)) | head -1
end
