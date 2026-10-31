function _ai_providers_cmd --description "ai providers: list providers (no network) or check one's reachability"
    # Read-only view (docs/refactoring.md Q7): providers are configured in the runner that
    # owns them (pi ~/.pi/agent/models.json, opencode ~/.config/opencode/config.json).
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: ai providers [ls]       List providers (no network)"
        echo "       ai providers check NAME Is it reachable right now?"
        echo ""
        echo "ollama is served by the native driver, claude by the claude CLI, every other"
        echo "provider by the runner (config key agent: pi or opencode), which also owns its"
        echo "configuration: add or change providers in pi (~/.pi/agent/models.json) or"
        echo "opencode (~/.config/opencode/config.json)."
        return 0
    end

    switch "$argv[1]"
        case ls list ''
            _ai_providers_ls
        case check
            _ai_providers_check $argv[2]
        case '*'
            set_color red
            echo "Unknown providers subcommand: $argv[1]"
            set_color normal
            echo "Run 'ai providers --help' for usage."
            return 1
    end
end
