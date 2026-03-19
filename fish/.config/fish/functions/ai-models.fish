function ai-models --description "Manage Ollama models: list, install, remove, set default"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: ai-models [COMMAND] [ARGS]"
        echo ""
        echo "Manage Ollama models."
        echo ""
        echo "Commands:"
        echo "  (none), list [FILTER]  Show models that fit in RAM (filter by name)"
        echo "  list --all [FILTER]    Show all models including oversized"
        echo "  install MODEL          Download a model"
        echo "  rm MODEL               Remove an installed model"
        echo "  use MODEL              Set default model for ai/ai-code"
        echo "  running                Show currently running models"
        echo ""
        echo "Examples:"
        echo "  ai-models                              Show models that fit"
        echo "  ai-models list --all                   Show all"
        echo "  ai-models list coder                   Filter by 'coder'"
        echo "  ai-models install qwen3:32b            Download model"
        echo "  ai-models use qwen2.5-coder:32b        Set default"
        echo "  ai-models rm codellama:13b             Remove model"
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
        case running ps
            _ai_models_running
        case list ''
            _ai_models_list $argv[2..]
        case '*'
            # Treat unknown command as filter for list
            _ai_models_list $argv
    end
end

# --- Cache paths ---
set -g _AI_REGISTRY_CACHE ~/.cache/ai-registry.json
set -g _AI_LOCAL_CACHE ~/.cache/ai-models.json

# --- Fetch helpers ---

function _ai_fetch_registry
    # Try remote API
    set -l response (curl -s --connect-timeout 5 https://ollama.com/api/tags 2>/dev/null)
    if test -n "$response"; and echo "$response" | jq -e '.models' &>/dev/null
        mkdir -p (dirname $_AI_REGISTRY_CACHE)
        echo "$response" >$_AI_REGISTRY_CACHE
        return 0
    end

    # Fallback to cache
    if test -f $_AI_REGISTRY_CACHE
        return 1
    end

    return 2
end

function _ai_fetch_local
    # Try local API
    if pgrep -q ollama
        set -l response (curl -s --connect-timeout 3 http://localhost:11434/api/tags 2>/dev/null)
        if test -n "$response"; and echo "$response" | jq -e '.models' &>/dev/null
            mkdir -p (dirname $_AI_LOCAL_CACHE)
            echo "$response" >$_AI_LOCAL_CACHE
            return 0
        end
    end

    # Fallback to cache
    if test -f $_AI_LOCAL_CACHE
        return 1
    end

    return 2
end

function _ai_get_installed_names
    set -l json
    if test -f $_AI_LOCAL_CACHE
        set json (cat $_AI_LOCAL_CACHE)
    end
    if test -n "$json"
        echo "$json" | jq -r '.models[].name' 2>/dev/null
    end
end

function _ai_format_size --argument-names bytes
    if test -z "$bytes"; or test "$bytes" = "0"; or test "$bytes" = null
        printf "  ?    "
        return
    end
    set -l gb (math -s1 "$bytes / 1073741824")
    printf "%6s" "$gb GB"
end

# --- List ---

function _ai_models_list
    set -l filter
    set -l show_all 0

    # Parse args
    for arg in $argv
        if test "$arg" = "--all" -o "$arg" = "-a"
            set show_all 1
        else
            set filter (string lower $arg)
        end
    end

    # RAM limit for filtering
    set -l ram_bytes (sysctl -n hw.memsize 2>/dev/null; or echo 0)
    set -l ram_gb (math -s0 "$ram_bytes / 1073741824")

    # Fetch registry
    _ai_fetch_registry
    set -l reg_status $status

    # Fetch local
    _ai_fetch_local
    set -l local_status $status

    # Status line
    if test $reg_status -eq 1 -a $local_status -eq 1
        set_color yellow
        echo "[offline mode — cached data]"
        set_color normal
        echo ""
    else if test $reg_status -eq 1
        set_color yellow
        echo "[registry offline — cached catalog]"
        set_color normal
        echo ""
    else if test $reg_status -eq 2
        set_color red
        echo "[registry unavailable — no cache]"
        set_color normal
        echo ""
    end

    set -l default_model (set -q AI_DEFAULT_MODEL; and echo $AI_DEFAULT_MODEL; or echo "")
    set -l installed (_ai_get_installed_names)

    # Read registry
    set -l registry_json
    if test -f $_AI_REGISTRY_CACHE
        set registry_json (cat $_AI_REGISTRY_CACHE)
    end

    if test -z "$registry_json"
        echo "No model catalog available."
        echo "Browse: https://ollama.com/library"
        return 1
    end

    # Extract registry models: name|size
    set -l models (echo "$registry_json" | jq -r '.models[] | "\(.name)|\(.size)"' 2>/dev/null)

    # Merge installed models not in registry
    set -l registry_names (echo "$registry_json" | jq -r '.models[].name' 2>/dev/null)
    set -l local_json
    if test -f $_AI_LOCAL_CACHE
        set local_json (cat $_AI_LOCAL_CACHE)
    end
    if test -n "$local_json"
        set -l local_models (echo "$local_json" | jq -r '.models[] | "\(.name)|\(.size)"' 2>/dev/null)
        for lm in $local_models
            set -l lname (string split "|" $lm)[1]
            if not contains -- $lname $registry_names
                set -a models $lm
            end
        end
    end

    # Sort
    set models (for m in $models; echo $m; end | sort)

    # Apply filter
    if test -n "$filter"
        set models (for m in $models; echo $m | string match -i "*$filter*"; end)
    end

    if test (count $models) -eq 0
        if test -n "$filter"
            echo "No models matching '$filter'"
        else
            echo "No models in catalog"
        end
        return 0
    end

    # Categorize and filter
    set -l total (count $models)
    set -l hidden 0
    set -l installed_count 0
    set -l coding
    set -l vision
    set -l general

    for entry in $models
        set -l parts (string split "|" $entry)
        set -l name $parts[1]
        set -l size_bytes $parts[2]

        # Skip unknown size
        if test -z "$size_bytes"; or test "$size_bytes" = "0"; or test "$size_bytes" = null
            set hidden (math $hidden + 1)
            continue
        end

        # RAM filter: skip oversized unless --all or installed
        set -l is_installed 0
        if contains -- $name $installed
            set is_installed 1
            set installed_count (math $installed_count + 1)
        end

        if test $show_all -eq 0
            set -l size_gb_raw (math -s0 "$size_bytes / 1073741824")
            if test $size_gb_raw -gt $ram_gb; and test $is_installed -eq 0
                set hidden (math $hidden + 1)
                continue
            end
        end

        # Categorize by name
        set -l lower_name (string lower $name)
        if string match -qi "*coder*" $lower_name; or string match -qi "*devstral*" $lower_name
            set -a coding $entry
        else if string match -qi "*vl*" $lower_name; or string match -qi "*vision*" $lower_name
            set -a vision $entry
        else
            set -a general $entry
        end
    end

    set -l shown (math (count $coding) + (count $vision) + (count $general))

    # Header
    set_color cyan
    printf "     %-26s %9s  %s\n" "Model" "Size" "Status"
    set_color normal
    echo " ───────────────────────────────────────────────────"

    # Print groups
    if test (count $coding) -gt 0
        _ai_print_group "Coding" $installed -- $coding
    end
    if test (count $general) -gt 0
        _ai_print_group "General" $installed -- $general
    end
    if test (count $vision) -gt 0
        _ai_print_group "Vision" $installed -- $vision
    end

    echo " ───────────────────────────────────────────────────"

    # Footer
    echo ""
    echo " $installed_count installed, $shown shown, $total available"
    if test $hidden -gt 0
        set_color yellow
        echo " $hidden models hidden (> $ram_gb GB RAM or unknown size) — use --all to show"
        set_color normal
    end
    if test -n "$filter"
        echo " Filter: $filter"
    end
    echo ""
    echo " Install: ai-models install MODEL"
    echo " Browse:  https://ollama.com/library"
end

function _ai_print_group --argument-names group_name
    set -l args $argv[2..]
    set -l default_model (set -q AI_DEFAULT_MODEL; and echo $AI_DEFAULT_MODEL; or echo "")

    # Split: installed names before --, model entries after --
    set -l installed_names
    set -l entries
    set -l past_sep 0
    for arg in $args
        if test "$arg" = "--"
            set past_sep 1
            continue
        end
        if test $past_sep -eq 0
            set -a installed_names $arg
        else
            set -a entries $arg
        end
    end

    set_color cyan
    echo " $group_name:"
    set_color normal

    for entry in $entries
        set -l parts (string split "|" $entry)
        set -l name $parts[1]
        set -l size_bytes $parts[2]
        set -l size_str (_ai_format_size $size_bytes)

        set -l is_installed (contains -- $name $installed_names; and echo 1; or echo 0)
        set -l is_default 0
        if test "$name" = "$default_model"
            set is_default 1
        end

        # Arrow for default, space otherwise
        if test $is_default -eq 1
            set_color yellow
            printf " > "
            set_color normal
        else
            printf "   "
        end

        # Checkmark for installed
        if test "$is_installed" = 1
            set_color green
            printf "✓ "
            set_color normal
        else
            printf "  "
        end

        # Name and size (size right-aligned)
        printf "%-26s %9s" $name $size_str

        # Status
        if test "$is_installed" = 1
            printf "  "
            set_color green
            printf "installed"
            set_color normal
        end

        echo
    end
end

# --- Install ---

function _ai_models_install
    if test (count $argv) -lt 1
        set_color red
        echo "Error: specify model — ai-models install MODEL"
        set_color normal
        return 1
    end

    _ai_ensure_running; or return 1

    set_color cyan
    echo "Installing: $argv[1]"
    set_color normal
    ollama pull $argv[1]

    if test $status -eq 0
        _ai_fetch_local
        echo "---"
        set_color green
        echo "Installed: $argv[1]"
        set_color normal
    else
        set_color red
        echo "Error: failed to install $argv[1]"
        set_color normal
        return 1
    end
end

# --- Use ---

function _ai_models_use
    if test (count $argv) -lt 1
        set_color red
        echo "Error: specify model — ai-models use MODEL"
        set_color normal
        return 1
    end

    _ai_fetch_local
    set -l installed (_ai_get_installed_names)

    if not contains -- $argv[1] $installed
        set_color red
        echo "Error: model '$argv[1]' is not installed"
        set_color normal
        echo "Install first: ai-models install $argv[1]"
        return 1
    end

    set -U AI_DEFAULT_MODEL $argv[1]
    echo "---"
    set_color green
    echo "Default model: $argv[1]"
    set_color normal
end

# --- Remove ---

function _ai_models_rm
    if test (count $argv) -lt 1
        set_color red
        echo "Error: specify model — ai-models rm MODEL"
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

# --- Running ---

function _ai_models_running
    if not pgrep -q ollama
        echo "Ollama is not running"
        return 0
    end

    set -l running (curl -s http://localhost:11434/api/ps 2>/dev/null | jq -r '.models[]? | "  \(.name)\t\(.size / 1073741824 | . * 10 | round / 10) GB"' 2>/dev/null)

    if test -z "$running"
        echo "No models running"
        return 0
    end

    set_color green
    echo "Running:"
    set_color normal
    for r in $running
        echo $r
    end
end
