function _ai_sessions --description "Manage chat sessions (ollama only)"
    set -l cmd
    if test (count $argv) -ge 1
        set cmd $argv[1]
    end

    if contains -- --help $argv; or contains -- -h $argv
        _ai_sessions_print_help
        return 0
    end

    switch "$cmd"
        case ls list ''
            _ai_sessions_ls $argv[2..]
        case show
            _ai_sessions_show $argv[2..]
        case info
            _ai_sessions_info $argv[2..]
        case rm remove delete
            _ai_sessions_rm $argv[2..]
        case rename mv
            _ai_sessions_rename $argv[2..]
        case branch fork
            _ai_sessions_branch $argv[2..]
        case archive
            _ai_sessions_archive $argv[2..]
        case restore unarchive
            _ai_sessions_restore $argv[2..]
        case edit
            _ai_sessions_edit $argv[2..]
        case export
            _ai_sessions_export $argv[2..]
        case import
            _ai_sessions_import $argv[2..]
        case clear
            _ai_sessions_clear $argv[2..]
        case pin
            _ai_sessions_pin $argv[2..]
        case unpin
            _ai_sessions_unpin $argv[2..]
        case move
            _ai_sessions_move $argv[2..]
        case search find
            _ai_sessions_search $argv[2..]
        case stats
            _ai_sessions_stats $argv[2..]
        case '*'
            set_color red
            echo "Unknown sessions subcommand: $cmd"
            set_color normal
            echo "Run 'ai sessions --help' for usage."
            return 1
    end
end

function _ai_sessions_print_help
    echo "Usage: ai sessions [SUBCOMMAND] [ARGS]"
    echo ""
    echo "Manage chat sessions (ollama only — claude conversations are managed by Claude CLI)."
    echo ""
    echo "Read / browse:"
    echo "  (none), ls [--archived]    List sessions"
    echo "  show NAME                  Render as markdown"
    echo "  info NAME                  Meta + token statistics"
    echo "  search QUERY               Find QUERY across messages"
    echo "  stats [--all]              Aggregated counts + token totals"
    echo "  export NAME [-f F] [PATH]  Export as md|json|jsonl"
    echo ""
    echo "Modify:"
    echo "  rm NAME [-f]               Delete"
    echo "  rename OLD NEW             Rename"
    echo "  clear NAME [-f]            Wipe messages (keep meta)"
    echo "  edit NAME                  Open in \$EDITOR (raw jsonl)"
    echo ""
    echo "Lifecycle:"
    echo "  branch SRC [NEW]           Fork a session"
    echo "  archive NAME               Hide from default ls"
    echo "  restore NAME               Un-archive"
    echo "  move NAME --to LAYER       Between project / global"
    echo "  import PATH [--name N]     Import a session file"
    echo ""
    echo "Pinning:"
    echo "  pin NAME --provider P --model M    Lock provider/model"
    echo "  unpin NAME                         Revert"
    echo ""
    echo "Resolving NAME: walk-up project .ai/sessions/, then global ~/.config/ai/sessions/."
    echo ""
    echo "Create or resume: ai chat --session NAME [--global] [--system \"...\"]"
    echo ""
    echo "Note: Claude sessions are not part of this — use 'claude --resume' / 'claude -c'."
end
