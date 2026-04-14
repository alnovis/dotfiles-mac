function _ai_models --description "Manage Ollama models: list, install, remove, set default"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: ai models [COMMAND] [ARGS]"
        echo ""
        echo "Manage Ollama models."
        echo ""
        echo "Commands:"
        echo "  (none), list [FILTER]  Show models that fit in RAM (filter by name)"
        echo "  list --all [FILTER]    Show all models including oversized"
        echo "  install MODEL          Download a model"
        echo "  rm MODEL               Remove an installed model"
        echo "  use MODEL              Set default model for ai/ai code"
        echo "  update                 Update all installed models to latest"
        echo "  info MODEL             Show model details (params, quant, context)"
        echo "  prune                  Clean up partial downloads and orphaned blobs"
        echo "  running                Show currently running models"
        echo ""
        echo "Examples:"
        echo "  ai models                              Show models that fit"
        echo "  ai models list --all                   Show all"
        echo "  ai models list coder                   Filter by 'coder'"
        echo "  ai models install qwen3:32b            Download model"
        echo "  ai models use qwen2.5-coder:32b        Set default"
        echo "  ai models rm codellama:13b             Remove model"
        echo "  ai models update                       Update all models"
        echo "  ai models info qwen2.5-coder:32b       Show model details"
        echo "  ai models prune                        Clean up disk"
        return 0
    end

    if not command -q ollama
        echo "Ollama is not installed"
        return 1
    end

    set -l cmd
    if test (count $argv) -ge 1
        set cmd $argv[1]
    end

    switch "$cmd"
        case install pull
            _ai_models_install $argv[2..]
        case use
            _ai_models_use $argv[2..]
        case rm remove
            _ai_models_rm $argv[2..]
        case update
            _ai_models_update
        case info show
            _ai_models_info $argv[2..]
        case prune cleanup
            _ai_models_prune
        case running ps
            _ai_models_running
        case list ''
            _ai_models_list $argv[2..]
        case '*'
            # Treat unknown command as filter for list
            _ai_models_list $argv
    end
end
