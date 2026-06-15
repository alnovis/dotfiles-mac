function _ai_gen --description "Generate content: commit, summary"
    set -l subcmd $argv[1]

    switch "$subcmd"
        case commit
            _ai_gen_commit $argv[2..]
        case summary
            _ai_gen_summary $argv[2..]
        case review
            set_color yellow
            echo "'ai gen review' moved to 'ai review' (now handles both project state and git changes)."
            echo "Run 'ai review --help' for the unified usage."
            set_color normal
            return 1
        case --help -h help ''
            echo "Usage: ai gen COMMAND [OPTIONS]"
            echo ""
            echo "Generate content using AI."
            echo ""
            echo "Commands:"
            echo "  commit              Generate commit message from staged changes"
            echo "  summary [DIR]       Generate project summary"
            echo ""
            echo "Common options:"
            echo "  --provider PROVIDER   Override provider (ollama, claude)"
            echo "  --model MODEL         Override model"
            echo "  --lang LANG           Response language (default: en)"
            echo "  -o, --output FILE     Save output to file"
            echo ""
            echo "Examples:"
            echo "  ai gen commit                     Generate commit message"
            echo "  ai gen summary -o summary.md      Save summary to file"
            echo ""
            echo "Note: project/file review is now 'ai review PATH' (was 'ai gen review')."
            return 0
        case '*'
            set_color red
            echo "Unknown gen command: $subcmd"
            set_color normal
            echo "Run 'ai gen --help' for usage."
            return 1
    end
end
