function _ai_review --description "AI code review — project state (path target) or git changes (branch/last/commit)"
    set -l orig_argv $argv

    argparse 'h/help' 'model=' 'provider=' 'lang=' 'lang-all=' 'o/output=' 'brief' 'dry-run' \
             'last=?' 'commit=' 'file=' 'with-project-context' -- $argv
    or return 1

    if set -q _flag_help
        _ai_review_print_help
        return 0
    end

    # Mode detection: first positional that exists on disk → target mode
    set -l mode git
    set -l first $argv[1]
    if test -n "$first"; and begin; test -d "$first"; or test -f "$first"; end
        set mode target
    end

    # Validate flag/mode compatibility
    if test "$mode" = target
        for f in last commit file
            if set -q _flag_$f
                set_color red
                echo "Error: --$f is git-mode only and cannot combine with a path target" >&2
                set_color normal
                return 1
            end
        end
    else
        if set -q _flag_with_project_context
            set_color red
            echo "Error: --with-project-context is target-mode only (needs a file path)" >&2
            set_color normal
            return 1
        end
    end

    switch $mode
        case target
            _ai_review_target $orig_argv
        case git
            _ai_review_git $orig_argv
    end
end

function _ai_review_print_help
    echo "Usage: ai review [OPTIONS] [TARGET|BASE] [\"custom prompt\"]"
    echo ""
    echo "AI code review. Two modes, auto-detected from the positional arg:"
    echo "  - target mode: TARGET is an existing file or directory → review project state"
    echo "  - git mode:    no path / BASE is a git ref → review git changes"
    echo ""
    echo "Common options:"
    echo "  --provider P            Override provider (ollama, claude)"
    echo "  --model MODEL           Override model"
    echo "  --lang LANG             Response language (default: en)"
    echo "  -o, --output FILE       Save output to file"
    echo "  --brief                 Short summary instead of detailed review"
    echo "  --dry-run               Print the assembled prompt without invoking the model"
    echo "  -h, --help              Show this help"
    echo ""
    echo "Git-mode options:"
    echo "  --last [N]              Review last N commit(s) (default: 1)"
    echo "  --commit SHA            Review a specific commit"
    echo "  --file FILE             Filter diff to a single file"
    echo "  --lang-all LANG         Full response + thinking in language (slower)"
    echo ""
    echo "Target-mode options:"
    echo "  --with-project-context  For file targets, include parent project context"
    echo ""
    echo "Examples — project state (target mode):"
    echo "  ai review .                              Review current project"
    echo "  ai review ~/work/myproject               Specific project"
    echo "  ai review src/Foo.scala                  Single file"
    echo "  ai review src/Foo.scala --with-project-context"
    echo "  ai review . \"focus on security\"          Custom prompt"
    echo "  ai review . --provider claude -o review.md"
    echo ""
    echo "Examples — git changes (git mode):"
    echo "  ai review                                Branch vs default base"
    echo "  ai review main                           Vs main branch"
    echo "  ai review --last                         Last commit"
    echo "  ai review --last 3                       Last 3 commits"
    echo "  ai review --commit abc1234               Specific commit"
    echo "  ai review --file src/Foo.scala           Filter diff to one file"
    echo "  ai review --brief --lang ru              Brief, in Russian"
    echo "  ai review --lang-all de                  Full review in German (incl. thinking)"
end
