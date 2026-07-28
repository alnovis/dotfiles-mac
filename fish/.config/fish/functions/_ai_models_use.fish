function _ai_models_use --description "Set the Ollama model — global default or per-task (chat/code/review/verify/commit/summary)"
    argparse 'h/help' 'task=' 'project' -- $argv; or return 1

    if set -q _flag_help
        _ai_models_use_help
        return 0
    end

    # Resolve TASK and MODEL from either form:
    #   ai models use MODEL                 → global default
    #   ai models use TASK MODEL            → per-task (TASK positional)
    #   ai models use MODEL --task TASK     → per-task (flag form, kept)
    set -l task
    set -l model

    if set -q _flag_task
        set task $_flag_task
        if test (count $argv) -ne 1
            _ai_models_use_err "with --task, give exactly one MODEL (got: $argv)"
            return 1
        end
        set model $argv[1]
    else
        switch (count $argv)
            case 0
                _ai_models_use_err "specify a model — see: ai models use --help"
                return 1
            case 1
                # A lone task name almost certainly means the model was forgotten.
                if _ai_is_task "$argv[1]"
                    _ai_models_use_err "'$argv[1]' is a task — give it a model: ai models use $argv[1] MODEL"
                    return 1
                end
                set model $argv[1]
            case 2
                set task $argv[1]
                set model $argv[2]
            case '*'
                _ai_models_use_err "too many arguments — use: ai models use [TASK] MODEL"
                return 1
        end
    end

    # Validate the task (positional or flag) up front — never silently ignore it.
    if test -n "$task"; and not _ai_is_task "$task"
        _ai_models_use_err "unknown task '$task' (valid: "(string join ', ' (_ai_tasks))", or 'all')"
        return 1
    end

    if set -q _flag_project; and test -z "$task"
        _ai_models_use_err "--project requires a task (the project layer is per-task only)"
        return 1
    end

    # ---- Per-task: trust the model string; write to the global or project layer ----
    if test -n "$task"
        set -l target_file ~/.config/ai/config
        set -l scope global
        if set -q _flag_project
            set target_file (_ai_project_config_target)
            set scope project
        end

        set -l tasks
        if test "$task" = all
            set tasks (_ai_tasks)
        else
            set tasks (string split , -- $task)
        end

        for t in $tasks
            _ai_config_write_file $target_file "$t"_model $model
        end
        echo "---"
        set_color green
        echo "Model for task(s) "(string join ", " $tasks)" → $model ($scope)"
        set_color normal
        return 0
    end

    # ---- Global default: must be an installed ollama model; sets the universal var ----
    _ai_fetch_local
    set -l installed (_ai_get_installed_names)
    if not contains -- $model $installed
        set_color red
        echo "Error: model '$model' is not installed" >&2
        set_color normal
        echo "Install first: ai models install $model" >&2
        return 1
    end

    set -U AI_DEFAULT_MODEL $model
    echo "---"
    set_color green
    echo "Default model: $model"
    set_color normal
end

function _ai_models_use_err
    set_color red
    echo "Error: $argv" >&2
    set_color normal
    echo "See: ai models use --help" >&2
end

function _ai_models_use_help
    echo "Usage: ai models use [TASK] MODEL [--project]"
    echo "       ai models use MODEL --task TASK[,TASK...] [--project]"
    echo ""
    echo "Set which Ollama model a task uses, or the global default model."
    echo ""
    echo "Forms:"
    echo "  ai models use MODEL                Set the global default (must be installed)"
    echo "  ai models use TASK MODEL           Set one task's model"
    echo "  ai models use TASK1,TASK2 MODEL    Set several tasks at once"
    echo "  ai models use all MODEL            Set every task"
    echo "  ai models use MODEL --task TASK    Same as 'use TASK MODEL' (flag form)"
    echo ""
    echo "Tasks: "(string join ", " (_ai_tasks))", all"
    echo ""
    echo "Layers:"
    echo "  (default)     Write to the global config (~/.config/ai/config)"
    echo "  --project     Write to the project .ai/config (requires a TASK)"
    echo ""
    echo "Notes:"
    echo "  - The global default (no TASK) is validated against installed models."
    echo "  - Per-task values are trusted as-is (may be a remote/uninstalled tag)."
    echo "  - Resolution per task: project > global config > AI_DEFAULT_MODEL > built-in."
    echo ""
    echo "Examples:"
    echo "  ai models use qwen2.5-coder:32b            Global default"
    echo "  ai models use verify north-mini-code-1.0   Verify uses north-mini"
    echo "  ai models use review,code qwen3.5:27b      Review + code together"
    echo "  ai models use chat qwen2.5-coder:7b --project   Per-project chat model"
    echo "  ai models use all north-mini-code-1.0      Every task → north-mini"
end
