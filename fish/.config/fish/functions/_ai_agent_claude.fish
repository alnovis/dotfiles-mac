function _ai_agent_claude --description "Runner: claude CLI (Anthropic models, subscription)"
    # Runner contract (docs/refactoring.md §4); the provider is always claude.
    #   --model M                passed through (sonnet, opus, haiku, or a full model id)
    #   --tools none|read|edit   none: `--strict-mcp-config --tools ""` (no built-in tools and no
    #                            claude.ai MCP connectors); read: Read, Grep, Glob; edit: default.
    #                            Default: read. Verified via the stream-json init event.
    #   --skill FILE             --append-system-prompt-file
    #   --interactive            claude REPL (with --continue / --resume)
    #   --no-session             --no-session-persistence
    # Non-interactive runs load no settings (--setting-sources ""), so no user hooks, and
    # no memory or CLAUDE.md: a review judges the code, not the notes about its author.
    # Non-interactive: the prompt comes on stdin. It must: --tools is variadic and would
    # swallow a prompt argument as a tool name.
    argparse 'provider=' 'model=' 'tools=' 'skill=' 'interactive' 'continue' 'resume' 'no-session' -- $argv; or return 1

    if not command -q claude
        set_color red
        echo "Error: claude is not installed" >&2
        set_color normal
        return 1
    end

    set -l args
    test -n "$_flag_model"; and set args --model $_flag_model
    set -q _flag_skill; and set -a args --append-system-prompt-file $_flag_skill

    if set -q _flag_interactive
        set -q _flag_continue; and set -a args --continue
        set -q _flag_resume; and set -a args --resume
        # The profile holds in the REPL too (`ai code` promises no edits without -e).
        # One comma-joined --tools value, then `--`: --tools is variadic.
        switch "$_flag_tools"
            case none
                set -a args --tools ""
            case read ''
                set -a args --tools Read,Grep,Glob
            case edit
            case '*'
                echo "claude: unknown tool profile '$_flag_tools' (none|read|edit)" >&2
                return 1
        end
        claude $args -- $argv
        return
    end

    set -q _flag_no_session; and set -a args --no-session-persistence
    # No user/project settings: their hooks (e.g. a UserPromptSubmit that appends notes)
    # would otherwise run inside a review and end up in the report. --bare would also
    # skip CLAUDE.md and memory, but it ignores OAuth (subscription) auth; the two switches
    # below skip them with OAuth kept (a review quoted "the memory notes" without them).
    set -a args --setting-sources ""

    # --tools goes last: it is variadic
    switch "$_flag_tools"
        case none
            set -a args --strict-mcp-config --tools ""
        case read ''
            set -a args --strict-mcp-config --tools Read Grep Glob
        case edit
        case '*'
            echo "claude: unknown tool profile '$_flag_tools' (none|read|edit)" >&2
            return 1
    end
    CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 CLAUDE_CODE_DISABLE_CLAUDE_MDS=1 claude -p $args
end
