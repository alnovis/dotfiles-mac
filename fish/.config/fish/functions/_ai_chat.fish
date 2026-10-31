function _ai_chat --description "Interactive chat with the chat task's provider; -c / -r continue or resume a past chat"
    argparse 'h/help' 'c/continue' 'r/resume' 'provider=' 'model=' 'dry-run' -- $argv; or return 1

    if set -q _flag_help
        echo "Usage: ai chat [MODEL] [--provider P] [-c | -r] [--dry-run]"
        echo ""
        echo "Interactive chat with the chat task's provider (chat_provider / chat_model)."
        echo "claude → the claude CLI; any other provider, ollama included → the runner"
        echo "(config key agent: pi or opencode), which keeps the chat history."
        echo ""
        echo "  MODEL, --model M     Override the model"
        echo "  --provider P         Override the provider"
        echo "  -c, --continue       Continue the last chat (the runner's / claude's history)"
        echo "  -r, --resume         Pick a past chat to resume"
        echo "  --dry-run            Show which executor would start, then exit"
        echo ""
        echo "For a bare 'ollama run' with no history: ai --provider ollama (no prompt)."
        return 0
    end

    # History lives in the runner (pi/opencode) or the claude CLI, so even ollama goes
    # through the runner here — `ollama run` keeps none (docs/refactoring.md Q4)
    set -l opts --runner
    set -q _flag_provider; and set -a opts --provider $_flag_provider
    set -q _flag_model; and set -a opts --model $_flag_model
    test (count $argv) -ge 1; and set -a opts --model $argv[1]
    set -q _flag_continue; and set -a opts --continue
    set -q _flag_resume; and set -a opts --resume
    set -q _flag_dry_run; and set -a opts --dry-run
    _ai_interactive --task chat --profile none $opts
end
