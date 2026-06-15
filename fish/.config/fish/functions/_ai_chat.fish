function _ai_chat --description "Chat: stateless ollama by default; --session for persistent REPL (ollama-only)"
    argparse 'h/help' 's/session=' 'c/continue' 'global' 'system=' 'provider=' 'model=' 'new' -- $argv; or return 1

    if set -q _flag_help
        echo "Usage: ai chat [MODEL]                    Stateless interactive (ollama)"
        echo "       ai chat --session NAME [OPTIONS]   Persistent REPL with stored history"
        echo ""
        echo "Stateless mode (no --session):"
        echo "  ai chat                     Run default chat model"
        echo "  ai chat gemma2:9b           Run specific model"
        echo ""
        echo "Session mode (ollama only):"
        echo "  --session NAME, -s NAME    Start/resume named session (walk-up or global)"
        echo "  --continue, -c             Continue last session (.last pointer)"
        echo "  --global                   Force global scope when creating new"
        echo "  --new                      Error if NAME already exists"
        echo "  --model MODEL              Override model for this session run"
        echo "  --system \"...\"             System prompt (only on first creation)"
        echo "  --provider PROV            Ollama only; claude blocked (use 'claude --resume')"
        echo ""
        echo "Examples:"
        echo "  ai chat --session debug-foo"
        echo "  ai chat -s debug-foo --model qwen2.5-coder:32b"
        echo "  ai chat -s general --global --system \"You are concise.\""
        echo ""
        echo "Note: claude sessions are managed by Claude CLI."
        echo "      Use 'claude --resume' / 'claude -c' to continue claude conversations."
        return 0
    end

    # Session mode?
    if set -q _flag_session; or set -q _flag_continue
        # Provider check: only ollama supported for sessions
        set -l provider
        if set -q _flag_provider
            set provider $_flag_provider
        else
            set provider (_ai_default_provider chat)
        end

        if test "$provider" != ollama
            set_color red
            echo "Error: sessions are supported for ollama provider only."
            set_color normal
            echo "For claude, use 'claude --resume' / 'claude -c' directly."
            echo "(claude CLI has its own session management.)"
            return 1
        end

        # Resolve session name
        set -l name
        if set -q _flag_continue
            set name (_ai_session_last)
            if test -z "$name"
                set_color red
                echo "Error: no recent session to continue."
                set_color normal
                echo "Start one: ai chat --session NAME"
                return 1
            end
        else
            set name $_flag_session
        end

        if test -z "$name"
            set_color red
            echo "Error: --session requires NAME (or use -c to continue last)."
            set_color normal
            return 1
        end

        # --new guard
        if set -q _flag_new
            set -l existing (_ai_session_file $name)
            if test -n "$existing"
                set_color red
                echo "Error: session '$name' already exists at: $existing"
                set_color normal
                return 1
            end
        end

        set -l session_args $name
        set -q _flag_global; and set -a session_args --global
        if set -q _flag_system; and test -n "$_flag_system"
            set -a session_args --system $_flag_system
        end
        if set -q _flag_model; and test -n "$_flag_model"
            set -a session_args --model $_flag_model
        end

        _ai_session_chat $session_args

        # Update .last pointer (in the dir of the actual file used)
        set -l file (_ai_session_file $name)
        if test -n "$file"
            _ai_session_set_last $file $name
        end
        return
    end

    # Stateless path (preserves prior behavior)
    set -l model $_flag_model
    if test -z "$model"
        set model (_ai_default_model chat ollama)
    end
    if test (count $argv) -ge 1
        set model $argv[1]
    end

    _ai_ensure_running; or return 1
    ollama run $model
end
