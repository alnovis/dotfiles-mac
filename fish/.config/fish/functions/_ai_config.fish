function _ai_config --description "View or set AI configuration"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: ai config [KEY] [VALUE]"
        echo ""
        echo "View or set AI configuration."
        echo "Config file: ~/.config/ai/config"
        echo ""
        echo "Keys:"
        echo "  provider    Default AI provider ("(string join ", " (_ai_providers))")"
        echo ""
        echo "Examples:"
        echo "  ai config                   Show all config"
        echo "  ai config provider          Show current provider"
        echo "  ai config provider claude   Set default provider"
        return 0
    end

    set -l key $argv[1]
    set -l value $argv[2]

    # No args: show all config
    if test -z "$key"
        set -l config_file ~/.config/ai/config
        if test -f $config_file
            cat $config_file
        else
            echo "No config file. Defaults:"
            echo "  provider=ollama"
        end
        return 0
    end

    # Validate key
    set -l valid_keys provider
    if not contains -- $key $valid_keys
        set_color red
        echo "Unknown config key: $key"
        set_color normal
        echo "Valid keys: $valid_keys"
        return 1
    end

    # Get
    if test -z "$value"
        set -l current (_ai_config_read $key)
        set -l has_value $status
        switch $key
            case provider
                set -l valid_providers (_ai_providers)
                if test $has_value -ne 0
                    set current ollama
                end
                echo "     Provider        Status"
                echo " ───────────────────────────"
                for p in $valid_providers
                    if test "$p" = "$current"
                        set_color green
                        printf " > %-18s active\n" $p
                        set_color normal
                    else
                        printf "   %s\n" $p
                    end
                end
                echo " ───────────────────────────"
        end
        return 0
    end

    # Set — validate value
    switch $key
        case provider
            set -l valid_providers (_ai_providers)
            if not contains -- $value $valid_providers
                set_color red
                echo "Unknown provider: $value"
                set_color normal
                echo "Valid providers: $valid_providers"
                return 1
            end
    end

    _ai_config_write $key $value
    set_color green
    echo "Set $key=$value"
    set_color normal
end
