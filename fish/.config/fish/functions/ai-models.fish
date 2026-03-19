function ai-models --description "Manage Ollama models: list, set default, remove"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: ai-models [COMMAND] [MODEL]"
        echo ""
        echo "Manage Ollama models."
        echo ""
        echo "Commands:"
        echo "  (none), list       Show catalog with installed/default marks"
        echo "  install MODEL      Download a model"
        echo "  rm MODEL           Remove an installed model"
        echo "  use MODEL          Set default model for ai/ai-code"
        echo ""
        echo "Examples:"
        echo "  ai-models                              Show catalog"
        echo "  ai-models install llama3.1:8b          Download model"
        echo "  ai-models use deepseek-coder-v2:16b    Set default"
        echo "  ai-models rm codellama:13b             Remove model"
        return 0
    end

    if not command -q ollama
        echo "Ollama is not installed"
        return 1
    end

    # Route subcommands
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
        case list ''
            _ai_models_list
        case '*'
            echo "Unknown command: $cmd"
            echo "Run: ai-models --help"
            return 1
    end
end

function _ai_models_list
    # Get installed models
    set -l installed
    if pgrep -q ollama
        set installed (ollama list 2>/dev/null | tail -n +2 | awk '{print $1}')
    else
        # Try starting to get list
        _ai_ensure_running 2>/dev/null
        set installed (ollama list 2>/dev/null | tail -n +2 | awk '{print $1}')
    end

    set -l default_model (set -q AI_DEFAULT_MODEL; and echo $AI_DEFAULT_MODEL; or echo "")

    # Model catalog: name, size, description
    set -l coding_models \
        "deepseek-coder-v2:16b|16GB|fast" \
        "qwen2.5-coder:7b|4.7GB|lightweight" \
        "qwen2.5-coder:32b|20GB|powerful" \
        "codellama:13b|7.4GB|Meta"

    set -l chat_models \
        "llama3.1:8b|4.7GB|general purpose" \
        "llama3.1:70b|40GB|powerful" \
        "gemma2:9b|5.4GB|Google" \
        "mistral:7b|4.1GB|fast"

    set_color cyan
    echo "Coding:"
    set_color normal
    _ai_models_print_group $coding_models

    echo ""
    set_color cyan
    echo "Chat:"
    set_color normal
    _ai_models_print_group $chat_models

    # Show installed models not in catalog
    set -l catalog deepseek-coder-v2:16b qwen2.5-coder:7b qwen2.5-coder:32b codellama:13b llama3.1:8b llama3.1:70b gemma2:9b mistral:7b
    set -l extra
    for m in $installed
        if not contains -- $m $catalog
            set -a extra $m
        end
    end
    if test (count $extra) -gt 0
        echo ""
        set_color cyan
        echo "Other installed:"
        set_color normal
        for m in $extra
            set_color green
            echo -n " ✓ "
            set_color normal
            printf "%-26s" $m
            if test "$m" = "$default_model"
                set_color yellow
                printf "★ default"
                set_color normal
            end
            echo
        end
    end

    # Running models
    if pgrep -q ollama
        set -l running (ollama ps 2>/dev/null | tail -n +2)
        if test -n "$running"
            echo ""
            set_color green
            echo "Running:"
            set_color normal
            echo "$running"
        end
    end

    echo ""
    echo "Install: ai-models install MODEL | Remove: ai-models rm MODEL"
    echo "Browse all: https://ollama.com/library"
end

function _ai_models_print_group
    set -l default_model (set -q AI_DEFAULT_MODEL; and echo $AI_DEFAULT_MODEL; or echo "")
    set -l installed (ollama list 2>/dev/null | tail -n +2 | awk '{print $1}')

    for entry in $argv
        set -l parts (string split "|" $entry)
        set -l name $parts[1]
        set -l size $parts[2]
        set -l desc $parts[3]

        set -l mark "   "
        if contains -- $name $installed
            set mark " ✓ "
        end

        if contains -- $name $installed
            set_color green
            echo -n "$mark"
            set_color normal
        else
            echo -n "$mark"
        end

        printf "%-26s %-6s %-16s" $name $size $desc

        if test "$name" = "$default_model"
            set_color yellow
            printf "★ default"
            set_color normal
        end

        echo
    end
end

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

function _ai_models_use
    if test (count $argv) -lt 1
        set_color red
        echo "Error: specify model — ai-models use MODEL"
        set_color normal
        return 1
    end

    _ai_ensure_running; or return 1

    set -l installed (ollama list 2>/dev/null | tail -n +2 | awk '{print $1}')
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

function _ai_models_rm
    if test (count $argv) -lt 1
        set_color red
        echo "Error: specify model — ai-models rm MODEL"
        set_color normal
        return 1
    end

    _ai_ensure_running; or return 1

    set -l model $argv[1]
    set -l installed (ollama list 2>/dev/null | tail -n +2 | awk '{print $1}')
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

    # Clear default if removed model was default
    if set -q AI_DEFAULT_MODEL; and test "$AI_DEFAULT_MODEL" = "$model"
        set -e AI_DEFAULT_MODEL
        set_color yellow
        echo "Cleared default (was $model)"
        set_color normal
    end

    echo "---"
    set_color green
    echo "Removed: $model"
    set_color normal
end
