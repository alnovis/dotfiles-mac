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

# --- Install ---

function _ai_models_install
    if test (count $argv) -lt 1
        set_color red
        echo "Error: specify model — ai models install MODEL"
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
        echo "Error: specify model — ai models use MODEL"
        set_color normal
        return 1
    end

    _ai_fetch_local
    set -l installed (_ai_get_installed_names)

    if not contains -- $argv[1] $installed
        set_color red
        echo "Error: model '$argv[1]' is not installed"
        set_color normal
        echo "Install first: ai models install $argv[1]"
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

# --- Running ---

function _ai_models_running
    if not pgrep -q ollama
        echo "Ollama is not running"
        return 0
    end

    set -l running (ollama ps 2>/dev/null | tail -n +2)

    if test -z "$running"
        echo "No models running"
        return 0
    end

    set_color green
    echo "Running:"
    set_color normal
    ollama ps 2>/dev/null
end

# --- Update ---

function _ai_models_update
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

# --- Info ---

function _ai_models_info
    if test (count $argv) -lt 1
        set_color red
        echo "Error: specify model — ai models info MODEL"
        set_color normal
        return 1
    end

    _ai_ensure_running; or return 1

    set -l model $argv[1]
    set -l info (curl -s http://localhost:11434/api/show -d "{\"name\": \"$model\", \"verbose\": true}" 2>/dev/null)

    if test -z "$info"; or echo "$info" | jq -e '.error' &>/dev/null
        set_color red
        echo "Error: model '$model' not found"
        set_color normal
        return 1
    end

    set -l default_model (set -q AI_DEFAULT_MODEL; and echo $AI_DEFAULT_MODEL; or echo "")

    # Extract details
    set -l family (echo $info | jq -r '.details.family // "unknown"')
    set -l params (echo $info | jq -r '.details.parameter_size // "unknown"')
    set -l quant (echo $info | jq -r '.details.quantization_level // "unknown"')
    set -l format (echo $info | jq -r '.details.format // "unknown"')
    set -l context (echo $info | jq -r '.model_info["general.context_length"] // .model_info["llama.context_length"] // "unknown"')
    set -l license (echo $info | jq -r '.license // empty' | head -1)
    set -l system (echo $info | jq -r '.system // empty' | head -3)

    # Size from local cache
    set -l size_str "unknown"
    if test -f $_AI_LOCAL_CACHE
        set -l size_bytes (cat $_AI_LOCAL_CACHE | jq -r --arg name "$model" '.models[] | select(.name == $name) | .size' 2>/dev/null)
        if test -n "$size_bytes"; and test "$size_bytes" != null
            set size_str (math -s1 "$size_bytes / 1073741824")" GB"
        end
    end

    # Display
    set_color cyan
    echo "Model: $model"
    set_color normal
    if test "$model" = "$default_model"
        set_color yellow
        echo "★ default"
        set_color normal
    end

    echo ""
    printf "  %-16s %s\n" "Family:" $family
    printf "  %-16s %s\n" "Parameters:" $params
    printf "  %-16s %s\n" "Quantization:" $quant
    printf "  %-16s %s\n" "Format:" $format
    printf "  %-16s %s\n" "Context:" $context
    printf "  %-16s %s\n" "Size:" $size_str

    if test -n "$license"
        echo ""
        set_color yellow
        echo "License:"
        set_color normal
        echo "  $license"
    end

    if test -n "$system"
        echo ""
        set_color yellow
        echo "System prompt:"
        set_color normal
        echo "$system" | while read -l line
            echo "  $line"
        end
    end
end

# --- Prune ---

function _ai_models_prune
    set -l blobs_dir ~/.ollama/models/blobs
    set -l manifests_dir ~/.ollama/models/manifests

    if not test -d $blobs_dir
        echo "No Ollama data found"
        return 0
    end

    echo "Scanning $blobs_dir..."

    # Find partial downloads
    set -l partials (find $blobs_dir -name "*-partial" -o -name "*.partial" -o -name "*.tmp" 2>/dev/null)
    set -l partial_count (count $partials)
    set -l partial_size 0

    if test $partial_count -gt 0
        for f in $partials
            set -l fsize (stat -f%z "$f" 2>/dev/null; or echo 0)
            set partial_size (math "$partial_size + $fsize")
        end
    end

    # Find orphaned blobs (not referenced by any manifest)
    set -l referenced_digests
    if test -d $manifests_dir
        set referenced_digests (find $manifests_dir -type f -exec cat {} \; 2>/dev/null | jq -r '.. | .digest? // empty' 2>/dev/null | sort -u)
    end

    set -l orphan_count 0
    set -l orphan_size 0
    set -l orphan_files

    for blob in (find $blobs_dir -type f -not -name "*-partial" -not -name "*.partial" -not -name "*.tmp" 2>/dev/null)
        set -l blob_name (basename $blob)
        # Convert filename format sha256-xxx to sha256:xxx for matching
        set -l blob_digest (string replace -a "-" ":" $blob_name)

        if not contains -- $blob_digest $referenced_digests
            set orphan_count (math $orphan_count + 1)
            set -l fsize (stat -f%z "$blob" 2>/dev/null; or echo 0)
            set orphan_size (math "$orphan_size + $fsize")
            set -a orphan_files $blob
        end
    end

    # Report
    set -l total_size (math "$partial_size + $orphan_size")
    set -l total_gb (math -s2 "$total_size / 1073741824")

    if test $partial_count -eq 0; and test $orphan_count -eq 0
        echo "---"
        set_color green
        echo "Clean — no orphaned data found"
        set_color normal
        return 0
    end

    if test $partial_count -gt 0
        set_color yellow
        echo "Partial downloads: $partial_count"
        set_color normal
        for f in $partials
            echo "  "(basename $f)
        end
    end

    if test $orphan_count -gt 0
        set_color yellow
        echo "Orphaned blobs: $orphan_count"
        set_color normal
    end

    echo ""
    echo "Reclaimable: $total_gb GB"
    echo ""

    read -l -P "Clean up? (y/N) " confirm
    if test "$confirm" != y -a "$confirm" != Y
        echo "Aborted"
        return 1
    end

    # Delete
    set -l deleted 0
    for f in $partials $orphan_files
        rm -f $f
        set deleted (math $deleted + 1)
    end

    echo "---"
    set_color green
    echo "Removed $deleted file(s), freed $total_gb GB"
    set_color normal
end
