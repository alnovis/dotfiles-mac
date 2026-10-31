function _ai_providers_check --description "Is provider NAME reachable right now? (the same probe as before a run)" --argument-names name
    if test -z "$name"
        set_color red
        echo "Error: ai providers check NAME"
        set_color normal
        return 1
    end

    switch $name
        case ollama
            set -l host (_ai_ollama_host)
            if _ai_url_reachable $host
                set_color green
                echo "ollama: reachable ($host)"
                set_color normal
                return 0
            end
            set_color red
            echo "ollama: not reachable ($host) — it is started on demand when local"
            set_color normal
            return 1
        case claude
            if command -q claude
                echo "claude: CLI installed — its connectivity is the CLI's own"
                return 0
            end
            set_color red
            echo "claude: CLI not installed"
            set_color normal
            return 1
    end

    set -l runner (_ai_default_agent); or return 1
    if not _ai_agent_{$runner}_models | string match -q -- (printf '%s\t*' $name)
        set_color red
        echo "$name: unknown to runner $runner (and not ollama / claude)" >&2
        set_color normal
        return 1
    end
    if not functions -q _ai_agent_{$runner}_probe
        echo "$name: runner $runner has no probe — can't tell"
        return 0
    end

    _ai_agent_{$runner}_probe $name
    switch $status
        case 0
            set_color green
            echo "$name: reachable (via $runner)"
            set_color normal
        case 1
            set_color red
            echo "$name: not reachable (via $runner) — off-network?"
            set_color normal
            return 1
        case '*'
            echo "$name: no URL in $runner's config (a built-in provider) — can't tell"
    end
end
