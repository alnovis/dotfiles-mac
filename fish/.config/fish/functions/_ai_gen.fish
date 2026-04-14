function _ai_gen --description "Generate content: review, commit, summary"
    set -l subcmd $argv[1]

    switch "$subcmd"
        case review
            _ai_gen_review $argv[2..]
        case commit
            _ai_gen_commit $argv[2..]
        case summary
            _ai_gen_summary $argv[2..]
        case --help -h help ''
            echo "Usage: ai gen COMMAND [OPTIONS]"
            echo ""
            echo "Generate content using AI."
            echo ""
            echo "Commands:"
            echo "  review [DIR]     Project review using meta-prompt"
            echo "  commit           Generate commit message from staged changes"
            echo "  summary [DIR]    Generate project summary"
            echo ""
            echo "Common options:"
            echo "  --provider PROVIDER   Override provider (ollama, claude)"
            echo "  --model MODEL         Override model"
            echo "  --lang LANG           Response language (default: en)"
            echo "  -o, --output FILE     Save output to file"
            echo ""
            echo "Examples:"
            echo "  ai gen review                     Review current project"
            echo "  ai gen review ~/work/myproject    Review specific project"
            echo "  ai gen review . \"focus on perf\"   Custom prompt"
            echo "  ai gen commit                     Generate commit message"
            echo "  ai gen summary -o summary.md      Save summary to file"
            echo "  ai gen review --provider claude   Use Claude for review"
            return 0
        case '*'
            set_color red
            echo "Unknown gen command: $subcmd"
            set_color normal
            echo "Run 'ai gen --help' for usage."
            return 1
    end
end
