function ai --description "AI toolkit: chat, code, review, gen, config, models, stop"
    set -l sub $argv[1]

    # ai <sub> [args...] → _ai_<sub> args...
    if contains -- "$sub" gen config models review code chat stop sessions
        _ai_$sub $argv[2..]
        return
    end

    if contains -- "$sub" --help -h help
        _ai_help
        return
    end

    # No subcommand → chat/prompt mode (also handles top-level --provider/--model/--think)
    _ai_run $argv
end

function _ai_help
    echo "Usage: ai [COMMAND] [OPTIONS] [PROMPT]"
    echo
    echo "AI toolkit — local (Ollama) and cloud (Claude) providers."
    echo
    echo "Commands:"
    echo "  (none) [PROMPT]      Interactive chat or one-shot prompt"
    echo "  gen                  Generate: commit, summary"
    echo "  config               View or set AI config (provider, etc.)"
    echo "  models               Manage models (list, install, rm, use, update, info, prune)"
    echo "  review               AI code review — project state (path) or git changes"
    echo "  code                 AI-assisted coding with aider"
    echo "  chat                 Chat model (--session NAME for persistent REPL, ollama only)"
    echo "  sessions             Manage chat sessions (ls, show, info, rm, rename)"
    echo "  stop                 Stop running models or server"
    echo
    echo "Options (for chat mode):"
    echo "  -m, --model MODEL       Use specific model"
    echo "  -t, --think             Enable thinking mode (ollama only)"
    echo "  --provider PROVIDER     Override provider (ollama, claude)"
    echo "  --dry-run               Print the assembled prompt without invoking the model"
    echo
    echo "Examples:"
    echo "  ai                               Interactive chat"
    echo "  ai \"explain this code\"            One-shot question"
    echo "  ai --provider claude \"question\"   Use Claude"
    echo "  ai -t \"solve this problem\"        With thinking"
    echo "  git diff | ai \"review this\"       Pipe input as context"
    echo "  ai review .                       Review current project"
    echo "  ai review src/Foo.scala           Review a single file"
    echo "  ai review --last 3                Review last 3 commits"
    echo "  ai review main                    Review branch vs main"
    echo "  ai gen commit                     Generate commit message"
    echo "  ai gen summary                    Generate project summary"
    echo "  ai config provider claude         Set default provider"
    echo "  ai models list coder              List coding models"
    echo "  ai code -e src/main/              Edit code with aider"
    echo "  ai stop                           Stop all models"
end
