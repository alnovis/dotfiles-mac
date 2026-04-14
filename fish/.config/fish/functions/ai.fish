function ai --description "AI toolkit: chat, code, review, gen, config, models, stop"
    set -l subcmd $argv[1]

    # Route subcommands
    switch "$subcmd"
        case gen
            _ai_gen $argv[2..]
        case config
            _ai_config $argv[2..]
        case models
            _ai_models $argv[2..]
        case review
            _ai_review $argv[2..]
        case code
            _ai_code $argv[2..]
        case chat
            _ai_chat $argv[2..]
        case stop
            _ai_stop $argv[2..]
        case --help -h help
            echo "Usage: ai [COMMAND] [OPTIONS] [PROMPT]"
            echo ""
            echo "AI toolkit — local (Ollama) and cloud (Claude) providers."
            echo ""
            echo "Commands:"
            echo "  (none) [PROMPT]      Interactive chat or one-shot prompt"
            echo "  gen                  Generate: review, commit, summary"
            echo "  config               View or set AI config (provider, etc.)"
            echo "  models               Manage models (list, install, rm, use, update, info, prune)"
            echo "  review               AI code review of branch or commits"
            echo "  code                 AI-assisted coding with aider"
            echo "  chat                 Chat model (default: llama3.1:8b)"
            echo "  stop                 Stop running models or server"
            echo ""
            echo "Options (for chat mode):"
            echo "  -m, --model MODEL       Use specific model"
            echo "  -t, --think             Enable thinking mode (ollama only)"
            echo "  --provider PROVIDER     Override provider (ollama, claude)"
            echo ""
            echo "Examples:"
            echo "  ai                               Interactive chat"
            echo "  ai \"explain this code\"            One-shot question"
            echo "  ai --provider claude \"question\"   Use Claude"
            echo "  ai -t \"solve this problem\"        With thinking"
            echo "  git diff | ai \"review this\"       Pipe input as context"
            echo "  ai gen review                     Project review"
            echo "  ai gen commit                     Generate commit message"
            echo "  ai gen summary                    Generate project summary"
            echo "  ai config provider claude         Set default provider"
            echo "  ai models list coder              List coding models"
            echo "  ai review --last 3                Review last 3 commits"
            echo "  ai code -e src/main/              Edit code with aider"
            echo "  ai stop                           Stop all models"
            return 0
        case '*'
            # No subcommand → chat/prompt mode
            _ai_run $argv
    end
end

function _ai_run --description "Run AI model interactively or with prompt"
    argparse 'm/model=' 't/think' 'provider=' -- $argv; or return 1

    set -l provider_args
    if set -q _flag_provider
        set -a provider_args --provider $_flag_provider
    end
    if set -q _flag_model
        set -a provider_args --model $_flag_model
    end
    if set -q _flag_think
        set -a provider_args --think
    end

    _ai_provider_run $provider_args $argv
end
