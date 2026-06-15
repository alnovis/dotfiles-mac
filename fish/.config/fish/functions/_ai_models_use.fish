function _ai_models_use --description "Set default Ollama model (global or per-task, global or project layer)"
    argparse 'task=' 'project' -- $argv; or return 1

    if test (count $argv) -lt 1
        set_color red
        echo "Error: specify model — ai models use MODEL [--task TASK] [--project]"
        set_color normal
        return 1
    end

    set -l model $argv[1]

    if set -q _flag_task
        # Per-task: trust the user; target = project or global
        set -l target_file ~/.config/ai/config
        set -l scope global
        if set -q _flag_project
            set target_file (_ai_project_config_target)
            set scope project
        end

        set -l tasks
        if test "$_flag_task" = all
            set tasks (_ai_tasks)
        else
            set tasks (string split , $_flag_task)
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

    # Global default (without --task): must be installed ollama model, sets the env var
    if set -q _flag_project
        set_color red
        echo "Error: --project requires --task TASK (project layer is per-task only)" >&2
        set_color normal
        return 1
    end

    _ai_fetch_local
    set -l installed (_ai_get_installed_names)

    if not contains -- $model $installed
        set_color red
        echo "Error: model '$model' is not installed"
        set_color normal
        echo "Install first: ai models install $model"
        return 1
    end

    set -U AI_DEFAULT_MODEL $model
    echo "---"
    set_color green
    echo "Default model: $model"
    set_color normal
end
