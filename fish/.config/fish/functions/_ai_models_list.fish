function _ai_models_list --description "List available Ollama models"
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

    set -l registry_cache ~/.cache/ai-registry.json
    set -l local_cache ~/.cache/ai-models.json

    # Read registry
    set -l registry_json
    if test -f $registry_cache
        set registry_json (cat $registry_cache)
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
    if test -f $local_cache
        set local_json (cat $local_cache)
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
    echo " Install: ai models install MODEL"
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
