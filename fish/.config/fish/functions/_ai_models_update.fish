function _ai_models_update --description "Update all installed Ollama models"
    _ai_ensure_running; or return 1

    set -l installed (_ai_get_installed_names)
    if test (count $installed) -eq 0
        echo "No models installed"
        return 0
    end

    echo "Updating "(count $installed)" model(s):"
    set -l updated 0
    set -l failed 0

    for model in $installed
        echo ""
        set_color cyan
        echo "Pulling: $model"
        set_color normal

        if ollama pull $model
            set updated (math $updated + 1)
        else
            set_color red
            echo "Failed: $model"
            set_color normal
            set failed (math $failed + 1)
        end
    end

    _ai_fetch_local

    echo ""
    echo "---"
    set_color green
    echo "Updated: $updated"
    set_color normal
    if test $failed -gt 0
        set_color red
        echo "Failed: $failed"
        set_color normal
    end
end
