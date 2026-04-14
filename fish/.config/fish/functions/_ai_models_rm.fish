function _ai_models_rm --description "Remove an installed Ollama model"
    if test (count $argv) -lt 1
        set_color red
        echo "Error: specify model — ai models rm MODEL"
        set_color normal
        return 1
    end

    _ai_ensure_running; or return 1

    set -l model $argv[1]
    set -l installed (_ai_get_installed_names)

    if not contains -- $model $installed
        set_color red
        echo "Error: model '$model' is not installed"
        set_color normal
        return 1
    end

    read -l -P "Remove $model? (y/N) " confirm
    if test "$confirm" != y -a "$confirm" != Y
        echo "Aborted"
        return 1
    end

    ollama rm $model

    if set -q AI_DEFAULT_MODEL; and test "$AI_DEFAULT_MODEL" = "$model"
        set -e AI_DEFAULT_MODEL
        set_color yellow
        echo "Cleared default (was $model)"
        set_color normal
    end

    _ai_fetch_local

    echo "---"
    set_color green
    echo "Removed: $model"
    set_color normal
end
