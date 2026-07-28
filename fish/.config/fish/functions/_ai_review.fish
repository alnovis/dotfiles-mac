function _ai_review --description "AI code review — project state (path target) or git changes (branch/last/commit)"
    set -l orig_argv $argv

    argparse 'h/help' 'model=' 'provider=' 'lang=' 'lang-all=' 'o/output=' 'brief' 'dry-run' \
             'last=?' 'commit=' 'file=' 'max-lines=' 'context-lines=' 'agentic' 'with-project-context' 'lens=' \
             'verify' 'no-verify' 'verify-provider=' 'verify-model=' 'verify-output=' 'verify-only=' -- $argv
    or return 1

    if set -q _flag_help
        _ai_review_print_help
        return 0
    end

    # --verify-only short-circuits both modes: re-verify an existing review file,
    # running no review pass at all.
    if set -q _flag_verify_only
        _ai_review_verify_only $orig_argv
        return $status
    end

    # Mode detection: first positional that exists on disk → target mode
    set -l mode git
    set -l first $argv[1]
    if test -n "$first"; and begin; test -d "$first"; or test -f "$first"; end
        set mode target
    end

    # Validate flag/mode compatibility
    if test "$mode" = target
        for f in last commit file max-lines context-lines
            if set -q _flag_(string replace -a - _ $f)
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
    echo "  --lens NAME[,NAME...]   Add specialist security checklist(s) to the review"
    echo "  --agentic               Skip embedding changed files — let the model explore"
    echo "                          the repo on its own. claude reads the repo either way"
    echo "                          (it is always tool-grounded); without --agentic the"
    echo "                          changed files are also embedded for focus. Local"
    echo "                          models need an agentic runner (pi) — roadmap."
    echo "  --context-lines N       Budget for embedding full changed files (git mode,"
    echo "                          default 2000). 0 = diff-only. Over budget → prompt/notice."
    echo "  --dry-run               Print the assembled prompt without invoking the model"
    echo "  -h, --help              Show this help"
    echo ""
    echo "Second-opinion verify (adversarial pass that tries to refute each finding):"
    echo "  --verify                Run a verify pass after the review"
    echo "  --no-verify             Disable verify (overrides a config default)"
    echo "  --verify-provider P     Provider for the verify pass (default: review provider)"
    echo "  --verify-model M        Model for the verify pass"
    echo "                          (claude reads the repo itself; ollama reasons from embedded code)"
    echo "  --verify-output FILE    Where the verify pass is written"
    echo "                          (default: <output>.verify.<ext>, alongside the review)"
    echo "  --verify-only FILE      Re-verify an EXISTING review file — no review pass."
    echo "                          Verify a costly claude review, or re-verify it with"
    echo "                          another model, without paying to regenerate it."
    echo ""
    echo "  With --verify, -o writes the RAW review and the verify pass goes to a"
    echo "  SEPARATE file, so the review is durable even if verify is interrupted."
    echo ""
    echo "Git-mode options:"
    echo "  --last [N]              Review last N commit(s) (default: 1)"
    echo "  --commit SHA            Review a specific commit"
    echo "  --file FILE             Filter diff to a single file"
    echo "  --max-lines N           Cap the diff at N lines (default: 500)"
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
    echo ""
    echo "Examples — security lenses (both modes):"
    echo "  ai review . --lens access-control        Add authorization checklist"
    echo "  ai review --lens crypto,logic-bug        Stack two lenses on the diff"
    echo "  ai review src/Auth.scala --lens access-control,deserialization"
    printf '  Available lenses: %s\n' (string join ', ' (_ai_review_lens))
    echo ""
    echo "Examples — verify pass:"
    echo "  ai review --verify -o review.md          review.md + review.verify.md"
    echo "  ai review --provider ollama --verify --verify-provider claude"
    echo "                                           Generate locally, verify with claude"
    echo "  ai review . --lens access-control --verify   Lens + verify together"
    echo "  ai review --verify-only review.md --provider claude"
    echo "                                           Re-verify a saved review with claude"
end
