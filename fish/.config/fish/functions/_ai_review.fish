function _ai_review --description "AI code review — project state (path target) or git changes (branch/last/commit)"
    # `--last` has an OPTIONAL arg (`last=?`), and fish argparse binds an optional
    # value ONLY when attached with '=' — so `--last 30` left the flag empty and
    # dropped 30 to a positional, silently reviewing just the last commit. Fold the
    # space form into `--last=N` up front (bare `--last` still means 1). This also
    # feeds the normalized args to _ai_review_git via orig_argv below.
    set -l norm
    set -l pending_last 0
    for a in $argv
        if test $pending_last -eq 1
            set pending_last 0
            if string match -qr '^[0-9]+$' -- $a
                set -a norm "--last=$a"
                continue
            end
            set -a norm --last # bare --last (next token isn't a number)
        end
        if test "$a" = --last
            set pending_last 1
        else
            set -a norm $a
        end
    end
    test $pending_last -eq 1; and set -a norm --last # trailing bare --last
    set argv $norm

    set -l orig_argv $argv

    argparse 'h/help' 'model=' 'provider=' 'lang=' 'lang-all=' 'o/output=' 'brief' 'dry-run' \
             'last=?' 'commit=' 'file=' 'max-lines=' 'context-lines=' 'agentic' 'no-think' 'with-project-context' 'lens=' \
             'verify' 'no-verify' 'verify-provider=' 'verify-model=' 'verify-output=' 'verify-only=' \
             'comments' 'range=' 'verdicts=' 'runs=' 'parallel' 'no-parallel' -- $argv
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
    # In a review the range is known (and anchoring takes it from there); an existing
    # verdicts file only makes sense with --verify-only
    for f in range verdicts
        if set -q _flag_$f
            set_color red
            echo "Error: --$f goes with --verify-only (a review knows its own range)" >&2
            set_color normal
            return 1
        end
    end

    # Mode detection: first positional that exists on disk → target mode
    set -l mode git
    set -l first $argv[1]
    if test -n "$first"; and begin; test -d "$first"; or test -f "$first"; end
        set mode target
    end

    # Validate flag/mode compatibility
    if test "$mode" = target
        for f in last commit file max-lines lang-all
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
    echo "  --provider P            Override provider (ollama, claude, or one the runner knows)"
    echo "  --model MODEL           Override model"
    echo "  --lang LANG             Response language (default: en)"
    echo "  -o, --output FILE       Save output to file"
    echo "  --brief                 Short 3-5 bullet summary instead of detailed review"
    echo "                          (--lens and --verify are ignored)"
    echo "  --lens NAME[,NAME...]   Add specialist checklist(s): security, quality, Rust,"
    echo "                          shell, data/messaging (see prompts/lenses/README.md)"
    echo "  --agentic               Embed only the diff / target file and let the model"
    echo "                          explore the repo read-only (claude via its CLI, other"
    echo "                          providers via the runner, config key: agent)."
    echo "                          Default: everything embedded, no tools."
    echo "  --no-think              Fast pass: disable a thinking model's reasoning"
    echo "  --context-lines N       Line budget for embedding whole files: the changed files"
    echo "                          in git mode (config key context_lines, default 2000), a"
    echo "                          directory's files in target mode (dir_context_lines,"
    echo "                          default 10000). 0 = none. Over budget → prompt/notice."
    echo "  --dry-run               Print the assembled prompt without invoking the model"
    echo "  -h, --help              Show this help"
    echo ""
    echo "Second-opinion verify (adversarial pass that tries to refute each finding):"
    echo "  --verify                Run a verify pass after the review"
    echo "  --no-verify             Disable verify (overrides a config default)"
    echo "  --verify-provider P     Provider for the verify pass (default: review provider)"
    echo "  --verify-model M        Model for the verify pass"
    echo "                          (with --agentic it reads the repo; otherwise it reasons"
    echo "                          from the embedded code)"
    echo "  --verify-output FILE    Where the verify pass is written"
    echo "                          (default: <output>.verify.<ext>, alongside the review)"
    echo "  --verify-only FILE      Re-verify an EXISTING review file — no review pass."
    echo "                          Verify a costly claude review, or re-verify it with"
    echo "                          another model, without paying to regenerate it."
    echo ""
    echo "  With --verify, -o writes the RAW review and the verify pass goes to a"
    echo "  SEPARATE file, so the review is durable even if verify is interrupted."
    echo ""
    echo "Merge-request comments (a third stage over the verdicts; turns --verify on):"
    echo "  --comments              Line comments from the [CONFIRMED] and [UNCERTAIN]"
    echo "                          findings: <output>.comments.md to check by hand,"
    echo "                          <output>.comments.json for GitLab/GitHub. Each line is"
    echo "                          found by its quoted code, so a wrong line number is"
    echo "                          fixed; a line outside the diff is marked. Needs -o."
    echo "  --runs N                Run the review N times and join them before verify:"
    echo "                          one run is a sample, several find more (turns --verify"
    echo "                          on). Default: config review_runs (scoped by provider/"
    echo "                          model, e.g. review_runs@litellm=3), else 1"
    echo "  --parallel, --no-parallel"
    echo "                          How those runs go. Default: config review_parallel"
    echo "                          (auto|on|off), auto = cloud in parallel, ollama in turn"
    echo "  --range BASE..HEAD      With --verify-only: the reviewed range, for anchoring"
    echo "  --verdicts FILE         With --verify-only: an existing verify file — no"
    echo "                          verify pass, comments only"
    echo ""
    echo "Git-mode options:"
    echo "  --last [N]              Review last N commit(s) (default: 1)"
    echo "  --commit SPEC           A commit (SHA), a range (A..B: after A up to B) or a task's"
    echo "                          commits (SHA1,SHA2,…). A range must be one linear piece of"
    echo "                          history: a merge or another commit inside is refused, and a"
    echo "                          broken list prints the pieces to review separately"
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
    echo "  ai review src/Foo.scala --brief          Short summary of one file"
    echo "  ai review . --provider claude -o review.md"
    echo ""
    echo "Examples — git changes (git mode):"
    echo "  ai review                                Branch vs default base"
    echo "  ai review main                           Vs main branch"
    echo "  ai review --last                         Last commit"
    echo "  ai review --last 3                       Last 3 commits"
    echo "  ai review --commit abc1234               Specific commit"
    echo "  ai review --commit abc1234~1..def5678    A range of commits"
    echo "  ai review --commit abc1234,def5678       A task's commits (checked contiguous)"
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
    echo "  ai review --last 2 --comments -o review.md   + review.comments.md/.json"
    echo "  ai review --verify-only review.md --verdicts review.verify.md --comments --range A~1..B"
    echo "  ai review --provider ollama --verify --verify-provider claude"
    echo "                                           Generate locally, verify with claude"
    echo "  ai review . --lens access-control --verify   Lens + verify together"
    echo "  ai review --verify-only review.md --provider claude"
    echo "                                           Re-verify a saved review with claude"
end
