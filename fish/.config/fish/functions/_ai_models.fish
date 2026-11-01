function _ai_models --description "Manage models: list installed, info, try/keep/drop, search, label, use"
    if contains -- --help $argv; or contains -- -h $argv
        # Subcommands with their own detailed help handle it themselves.
        if test "$argv[1]" = use
            _ai_models_use --help
            return $status
        end
        echo "Usage: ai models [COMMAND] [ARGS]"
        echo ""
        echo "Manage models. Without a command: the installed ollama models (no network)."
        echo ""
        echo "Commands:"
        echo "  (none), list [FILTER]  Installed models: one row per model, grouped by label,"
        echo "                         with size, capabilities, the tasks using it, trials"
        echo "  --provider P           The table of provider P: context, type, price (ollama:"
        echo "                         the local table; all: one table per provider)"
        echo "  info NAME[:TAG]        Details; for a model not installed, from the ollama"
        echo "                         registry (download size, RAM fit, params, vision, …)"
        echo "  try NAME:TAG           Show info, confirm, pull, mark as a trial"
        echo "  keep NAME              End a trial, keep the model"
        echo "  drop NAME              Remove a model (all its tags) and its metadata"
        echo "  search [QUERY]         Open ollama.com search (ollama has no search API)"
        echo "  label [--provider P] NAME LABEL"
        echo "                         Group a model (LABEL general clears it); --provider"
        echo "                         for a cloud or claude model"
        echo "  use [TASK] MODEL       Set the default model, or a task's model"
        echo "                         (TASK: chat/code/review/verify/commit/summary/all)"
        echo "  install MODEL          Pull a model (no trial mark)"
        echo "  rm MODEL               Remove one tag"
        echo "  update                 Update all installed models to latest"
        echo "  prune                  Clean up partial downloads and orphaned blobs"
        echo "  running                Show currently running models"
        echo ""
        echo "Examples:"
        echo "  ai models                              Installed models"
        echo "  ai models coder                        Only names containing 'coder'"
        echo "  ai models --provider litellm           The litellm models: context, type, price"
        echo "  ai models --provider all               One table per provider"
        echo "  ai models search qwen                  Find models on ollama.com"
        echo "  ai models info qwen3:30b               Will it fit? (before downloading)"
        echo "  ai models try qwen3:30b                Pull it as a trial"
        echo "  ai models keep qwen3:30b               It's a keeper"
        echo "  ai models label qwen3:30b coding       Group it under Coding"
        echo "  ai models use review qwen3:30b         Use it for reviews"
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
        case list ''
            _ai_models_list $argv[2..]
        case '--provider*'
            _ai_models_list $argv
        case info show
            _ai_models_info $argv[2..]
        case try
            _ai_models_try $argv[2..]
        case keep
            _ai_models_keep $argv[2..]
        case drop
            _ai_models_drop $argv[2..]
        case search
            _ai_models_search $argv[2..]
        case label
            _ai_models_label $argv[2..]
        case use
            _ai_models_use $argv[2..]
        case install pull
            _ai_models_install $argv[2..]
        case rm remove
            _ai_models_rm $argv[2..]
        case update
            _ai_models_update
        case prune cleanup
            _ai_models_prune
        case running ps
            _ai_models_running
        case '*'
            # Anything else filters the installed list
            _ai_models_list $argv
    end
end
