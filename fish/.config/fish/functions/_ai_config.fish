function _ai_config --description "View or set AI configuration (global or project)"
    argparse 'h/help' 'task=' 'project' 'to=' -- $argv; or return 1

    if set -q _flag_help
        _ai_config_print_help
        return 0
    end

    set -l key $argv[1]
    set -l value $argv[2]

    set -l scope global
    set -q _flag_project; and set scope project

    if test -z "$key"
        _ai_config_show_all
        return 0
    end

    switch $key
        case tasks
            _ai_tasks
            return 0
        case status
            _ai_config_do_status
            return
        case reset
            _ai_config_do_reset "$_flag_task" $scope
            return
        case provider
            _ai_config_do_provider "$value" "$_flag_task" $scope
            return
        case move
            _ai_config_do_move "$_flag_task" "$_flag_to"
            return
        case '*'
            set_color red
            echo "Unknown config key: $key"
            set_color normal
            echo "Run 'ai config --help' for usage."
            return 1
    end
end

function _ai_config_print_help
    echo "Usage: ai config [SUBCOMMAND] [VALUE] [--task TASK] [--project]"
    echo ""
    echo "View or set AI configuration."
    echo ""
    echo "Subcommands:"
    echo "  (none)                    Show both project and global config"
    echo "  provider [PROV]           Show or set provider"
    echo "  status                    Resolved per-task view + origin of each value"
    echo "  reset --task X            Clear per-task config for X (or 'all')"
    echo "  move --task X --to LAYER  Move per-task keys between layers"
    echo "  tasks                     List known tasks"
    echo ""
    echo "Scope flags:"
    echo "  --task TASK               Apply to task (comma-list or 'all')"
    echo "  --project                 Write/clear in project .ai/config (default: global ~/.config/ai/config)"
    echo "  --to {project|global}     Move target layer (for 'move')"
    echo ""
    echo "Examples:"
    echo "  ai config                                Show project + global"
    echo "  ai config status                         Resolved per task with origin"
    echo "  ai config provider claude                Set global provider"
    echo "  ai config provider claude --task review  Global, for one task"
    echo "  ai config provider claude --task review --project"
    echo "  ai config reset --task review            Clear global per-task"
    echo "  ai config reset --task all --project     Clear all per-task in project"
    echo "  ai config move --task review --to project"
    echo "  ai config move --task all --to global"
end

function _ai_config_target_file --argument-names scope
    if test "$scope" = project
        _ai_project_config_target
    else
        echo ~/.config/ai/config
    end
end

function _ai_config_expand_tasks --argument-names spec
    if test "$spec" = all
        _ai_tasks
    else
        string split , $spec
    end
end

function _ai_config_show_all
    set -l proj (_ai_project_config_file)
    if test -n "$proj"
        set_color cyan
        echo "[project] $proj"
        set_color normal
        cat $proj
        echo
    end

    set_color cyan
    echo "[global] ~/.config/ai/config"
    set_color normal
    set -l global_file ~/.config/ai/config
    if test -f $global_file; and test -s $global_file
        cat $global_file
    else
        echo "(empty — defaults apply)"
    end
end

function _ai_config_do_status
    set -l proj (_ai_project_config_file)

    set_color cyan
    echo "Sources:"
    set_color normal
    if test -n "$proj"
        echo "  project = $proj"
    else
        echo "  project = (none — no .ai/config in walked-up tree)"
    end
    echo "  global  = ~/.config/ai/config"
    if set -q AI_DEFAULT_MODEL; and test -n "$AI_DEFAULT_MODEL"
        echo "  env     = AI_DEFAULT_MODEL=$AI_DEFAULT_MODEL"
    end
    echo

    set_color cyan
    echo "Resolved per task:"
    set_color normal

    set -l labels default (_ai_tasks)
    for t in $labels
        set -l p
        set -l m
        set -l p_orig
        set -l m_orig

        if test "$t" = default
            set p (_ai_default_provider)
            set p_orig (_ai_origin_provider)
            set m (_ai_default_model "" $p)
            set m_orig (_ai_origin_model "" $p)
        else
            set p (_ai_default_provider $t)
            set p_orig (_ai_origin_provider $t)
            set m (_ai_default_model $t $p)
            set m_orig (_ai_origin_model $t $p)
        end

        if test -n "$m"
            printf "  %-9s %s / %-30s  (provider: %s | model: %s)\n" "$t:" $p $m $p_orig $m_orig
        else
            printf "  %-9s %s / (provider default)             (provider: %s | model: —)\n" "$t:" $p $p_orig
        end
    end
end

function _ai_config_do_provider --argument-names value task scope
    set -l valid_providers (_ai_providers)
    set -l target_file (_ai_config_target_file $scope)

    # Show form
    if test -z "$value"
        if test -n "$task"
            _ai_config_show_provider_task $task $scope
        else
            _ai_config_show_provider_global $scope
        end
        return 0
    end

    # Validate value
    if not contains -- $value $valid_providers
        set_color red
        echo "Unknown provider: $value"
        set_color normal
        echo "Valid providers: $valid_providers"
        return 1
    end

    if test "$value" = claude; and not command -q claude
        set_color yellow
        echo "Warning: claude is not installed — tasks using this provider will fail at runtime." >&2
        set_color normal
    end

    # Set
    if test -n "$task"
        set -l tasks (_ai_config_expand_tasks $task)
        for t in $tasks
            _ai_config_write_file $target_file "$t"_provider $value
        end
        set_color green
        echo "Set provider for task(s) "(string join ", " $tasks)" → $value ($scope)"
        set_color normal
    else
        _ai_config_write_file $target_file provider $value
        set_color green
        echo "Set $scope provider: $value"
        set_color normal
    end
end

function _ai_config_show_provider_global --argument-names scope
    set -l current (_ai_default_provider)
    set -l valid_providers (_ai_providers)
    echo "     Provider        Status ($scope)"
    echo " ────────────────────────────────"
    for p in $valid_providers
        if test "$p" = "$current"
            set_color green
            printf " > %-18s active\n" $p
            set_color normal
        else
            printf "   %s\n" $p
        end
    end
    echo " ────────────────────────────────"
end

function _ai_config_show_provider_task --argument-names task scope
    set -l current (_ai_default_provider $task)
    set -l valid_providers (_ai_providers)
    set -l target_file (_ai_config_target_file $scope)
    set -l direct (_ai_config_read_file $target_file "$task"_provider)
    set -l is_inherit 0
    if test $status -ne 0; or test -z "$direct"
        set is_inherit 1
    end

    echo "     Provider (task: $task, scope: $scope)"
    echo " ─────────────────────────────────────────"
    for p in $valid_providers
        if test "$p" = "$current"
            set_color green
            if test $is_inherit -eq 1
                printf " > %-18s active (inherited)\n" $p
            else
                printf " > %-18s active\n" $p
            end
            set_color normal
        else
            printf "   %s\n" $p
        end
    end
    echo " ─────────────────────────────────────────"
end

function _ai_config_do_reset --argument-names task scope
    if test -z "$task"
        set_color red
        echo "Error: reset requires --task TASK (or --task all)"
        set_color normal
        return 1
    end

    set -l target_file (_ai_config_target_file $scope)
    set -l tasks (_ai_config_expand_tasks $task)

    for t in $tasks
        _ai_config_remove_file $target_file "$t"_provider
        _ai_config_remove_file $target_file "$t"_model
    end

    set_color green
    echo "Reset per-task config ($scope) for: "(string join ", " $tasks)
    set_color normal
end

function _ai_config_do_move --argument-names task to
    if test -z "$task"
        set_color red
        echo "Error: move requires --task TASK (or --task all)"
        set_color normal
        return 1
    end
    if test "$to" != project; and test "$to" != global
        set_color red
        echo "Error: --to must be 'project' or 'global'"
        set_color normal
        return 1
    end

    set -l target_file
    set -l source_file
    if test "$to" = global
        set source_file (_ai_project_config_target)
        set target_file ~/.config/ai/config
    else
        set source_file ~/.config/ai/config
        set target_file (_ai_project_config_target)
    end

    set -l tasks (_ai_config_expand_tasks $task)

    set -l moved
    for t in $tasks
        for k in "$t"_provider "$t"_model
            set -l v (_ai_config_read_file $source_file $k)
            if test $status -eq 0; and test -n "$v"
                _ai_config_write_file $target_file $k $v
                _ai_config_remove_file $source_file $k
                set -a moved "$k=$v"
            end
        end
    end

    if test (count $moved) -eq 0
        set_color yellow
        echo "Nothing to move (no per-task keys in source layer)"
        set_color normal
        return 0
    end

    set_color green
    echo "Moved to $to:"
    for m in $moved
        echo "  $m"
    end
    set_color normal
end
