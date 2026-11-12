function ai --description "AI toolkit: chat, code, review, lessons, gen, config, providers, models, stop"
    set -l sub $argv[1]

    # ai <sub> [args...] → _ai_<sub> args...
    if contains -- "$sub" gen config models review lessons code chat stop
        _ai_$sub $argv[2..]
        return
    end

    # `providers` has its own entry point: _ai_providers is the discovery helper
    if test "$sub" = providers
        _ai_providers_cmd $argv[2..]
        return
    end

    if contains -- "$sub" --help -h help
        _ai_help
        return
    end

    # A word that is another command's subcommand, unquoted, is a typo in the command, not a
    # question: "ai show gemma4:26b" (for ai models show) went to the model as a prompt, and
    # the model explained that Gemma 4 does not exist. A quoted prompt is one argument with
    # spaces and passes; so does one that starts with an option.
    if set -q argv[1]; and not string match -q -- '-*' $argv[1]; and not string match -q -- '* *' $argv[1]
        set -l parent
        switch $argv[1]
            case show info list install rm use update prune running try keep drop label search
                set parent models
            case commit summary
                set parent gen
            case mark stats open edit
                set parent lessons
            case status set reset move
                set parent config
            case ls check
                set parent providers
        end
        if test -n "$parent"
            set_color red
            echo "ai: no command '$argv[1]'. Did you mean: ai $parent $argv" >&2
            set_color normal
            echo "    To ask the model, quote the prompt: ai \"$argv\"" >&2
            return 1
        end
    end

    # No subcommand → chat/prompt mode (also handles top-level --provider/--model/--think)
    _ai_run $argv
end

function _ai_help
    echo "Usage: ai [COMMAND] [OPTIONS] [PROMPT]"
    echo
    echo "AI toolkit — local and cloud models: native ollama, the claude CLI, and runners (pi, opencode)."
    echo
    echo "Commands:"
    echo "  (none) [PROMPT]      Interactive chat or one-shot prompt"
    echo "  gen                  Generate: commit, summary"
    echo "  config               View or set AI config (provider, etc.)"
    echo "  providers            List providers and their executors; check NAME = reachable?"
    echo "  models               Manage models (list, install, rm, use, update, info, prune, running, label)"
    echo "  review               AI code review — project state (path) or git changes"
    echo "  lessons              Log what you marked in review comments; how right reviews were"
    echo "  code                 Interactive coding session (code task's provider, via its runner)"
    echo "  chat                 Interactive chat (chat task's provider, history via the runner; -c/-r)"
    echo "  stop                 Stop running models or server"
    echo
    echo "Options (for chat mode):"
    echo "  -m, --model MODEL       Use specific model"
    echo "  -t, --think             Enable thinking mode (ollama only)"
    echo "  --provider PROVIDER     Override provider (ollama, claude, or one the runner knows)"
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
    echo "  ai code -e @src/main/             Coding session with edits allowed"
    echo "  ai stop                           Stop all models"
end
