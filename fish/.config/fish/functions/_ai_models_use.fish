function _ai_models_use --description "Set default Ollama model"
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
