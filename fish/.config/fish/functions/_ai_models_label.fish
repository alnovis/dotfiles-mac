function _ai_models_label --description "Set the grouping label of a model (general clears it); --provider P for a model of a runner provider or claude"
    # A label says what you keep the model for (e.g. coding) — capabilities can't tell that.
    # An installed ollama model is stored per digest, so every tag shares it (docs/refactoring.md
    # §7a). A cloud model has no digest: its key is "@PROVIDER/MODEL", which no digest can be.
    argparse 'provider=' -- $argv; or return 1
    set -l name $argv[1]
    set -l label $argv[2]
    if test -z "$name"; or test -z "$label"
        set_color red
        echo "Error: ai models label [--provider P] NAME LABEL   (LABEL general clears it)"
        set_color normal
        return 1
    end

    set -l key
    set -l model
    if set -q _flag_provider; and test "$_flag_provider" != ollama
        set -l provider $_flag_provider
        set model $name
        set -l known
        if test $provider = claude
            set known (_ai_agent_claude_models | string split -f2 \t)
        else
            set -l runner (_ai_default_agent); or return 1
            set known (_ai_agent_{$runner}_models | string match -r -g (printf '^%s\t(.+)$' (string escape --style=regex -- $provider)))
        end
        if not contains -- $model $known
            echo "Error: $provider has no model $model (ai models --provider $provider)" >&2
            return 1
        end
        set key "@$provider/$model"
    else
        set model (_ai_model_norm $name)
        _ai_fetch_local >/dev/null
        set key (_ai_model_digest $model)
        if test -z "$key"
            echo "Error: $model is not installed" >&2
            return 1
        end
    end

    set label (string lower -- $label)
    if test "$label" = general
        _ai_models_meta_set $key label ''
        echo "$model → General"
    else
        _ai_models_meta_set $key name $model
        _ai_models_meta_set $key label $label
        echo "$model → $label"
    end
end
