function _ai_models_try --description "Pull a model as a trial: show its registry details, confirm, pull, mark it (keep / drop later)"
    argparse y/yes -- $argv; or return 1
    if test (count $argv) -lt 1
        set_color red
        echo "Error: specify model — ai models try NAME:TAG"
        set_color normal
        return 1
    end
    set -l model (_ai_model_norm $argv[1])

    _ai_fetch_local >/dev/null
    if test -n "$(_ai_model_digest $model)"
        echo "$model is already installed — ai models info $model"
        return 0
    end

    _ai_models_info_remote $model; or return 1

    if not set -q _flag_yes
        echo
        read -l -P "Pull $model as a trial? [y/N] " confirm
        if test "$confirm" != y -a "$confirm" != Y
            echo Aborted
            return 1
        end
    end

    _ai_ensure_running; or return 1
    ollama pull $model; or return 1

    _ai_fetch_local >/dev/null
    set -l digest (_ai_model_digest $model)
    if test -z "$digest"
        echo "Pulled, but $model is not in the installed list — not marked as a trial" >&2
        return 1
    end
    _ai_models_meta_set $digest name $model
    _ai_models_meta_set $digest trial (date -u +"%Y-%m-%dT%H:%M:%SZ")

    echo "---"
    set_color green
    echo "Trial: $model"
    set_color normal
    echo "  Keep it: ai models keep $model · remove it: ai models drop $model"
end
