function _ai_agent_opencode --description "Runner: opencode (any provider in opencode's own config, local or cloud)"
    # Runner contract (docs/refactoring.md §4):
    #   --provider P --model M   opencode model id P/M (M may already be "P/id")
    #   --tools none|read|edit   one opencode agent per profile: ai-none / ai-read / ai-edit
    #                            (agents/.config/opencode/agents/ in dotfiles). Default: read.
    #   --skill FILE             prepended to the prompt — opencode has no per-run system-prompt
    #                            flag (an agent's body is its system prompt)
    #   --interactive            opencode TUI (with --continue); agent and model are picked in
    #                            the TUI, which has no flags for them — so only --tools edit is
    #                            accepted, and a --model is reported as not applied
    # `command opencode`, not `opencode`: the user-facing `opencode` wrapper auto-starts
    # ollama, which a cloud-provider run must not need.
    #   --no-session             accepted for symmetry; `opencode run` always keeps a session
    # Runs through opencode's background service: `--standalone` does not load the ollama provider.
    argparse 'provider=' 'model=' 'tools=' 'skill=' 'interactive' 'continue' 'resume' 'no-session' -- $argv; or return 1

    if not command -q opencode
        set_color red
        echo "Error: opencode is not installed — brew install opencode" >&2
        set_color normal
        return 1
    end

    test "$_flag_provider" = ollama; and begin
        _ai_ensure_running; or return 1
    end

    if set -q _flag_interactive
        # The TUI has no flags for the agent or the model, so a profile below edit can't be
        # enforced — refuse rather than open a TUI that can edit after `ai code` promised not to
        if test "$_flag_tools" != edit
            echo "opencode: the TUI can't restrict tools (profile '$_flag_tools'). Use -e/--edit to accept its full toolset, or set agent=pi" >&2
            return 1
        end
        test -n "$_flag_model"; and echo "opencode: the TUI picks the model itself — '$_flag_model' is not applied; choose it in the TUI" >&2
        set -l args
        set -q _flag_continue; and set args --continue
        command opencode $args $argv
        return
    end

    set -l agent
    switch "$_flag_tools"
        case none
            set agent ai-none
        case read ''
            set agent ai-read
        case edit
            set agent ai-edit
        case '*'
            echo "opencode: unknown tool profile '$_flag_tools' (none|read|edit)" >&2
            return 1
    end

    set -l args --agent $agent
    # A slash inside the id (huihui_ai/glm…) is not a provider prefix
    if test -n "$_flag_model"
        if test -z "$_flag_provider"; or string match -q -- "$_flag_provider/*" $_flag_model
            set -a args -m $_flag_model
        else
            set -a args -m $_flag_provider/$_flag_model
        end
    end

    if set -q _flag_skill
        begin
            cat $_flag_skill
            echo
            cat
        end | command opencode run $args $argv
    else
        command opencode run $args $argv
    end
end
