function _ai_models_install --description "Download an Ollama model"
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
