function _ai_gen_commit --description "Generate commit message from uncommitted changes"
    argparse 'h/help' 'provider=' 'model=' 'l/lang=' 'o/output=' -- $argv; or return 1

    if set -q _flag_help
        echo "Usage: ai gen commit [OPTIONS]"
        echo ""
        echo "Generate a commit message from uncommitted changes."
        echo "Uses staged changes if available, otherwise all unstaged changes."
        echo "Default prompt: ~/.config/fish/prompts/meta-commit.md"
        echo ""
        echo "Options:"
        echo "  --provider PROVIDER   Override provider"
        echo "  --model MODEL         Override model"
        echo "  -l, --lang LANG       Response language (default: en)"
        echo "  -o, --output FILE     Save to file"
        echo "  -h, --help            Show this help"
        echo ""
        echo "Examples:"
        echo "  ai gen commit                        Generate commit message"
        echo "  ai gen commit --provider claude      Use Claude"
        echo "  ai gen commit --lang ru              In Russian"
        return 0
    end

    # Must be in a git repo
    if not git rev-parse --show-toplevel &>/dev/null
        set_color red
        echo "Not a git repository"
        set_color normal
        return 1
    end

    # Get changes: staged first, then unstaged
    set -l diff (git diff --staged)
    set -l diff_source "staged"
    if test -z "$diff"
        set diff (git diff)
        set diff_source "unstaged"
    end
    if test -z "$diff"
        echo "No changes to commit"
        return 1
    end

    # Resolve provider
    set -l provider
    if set -q _flag_provider
        set provider $_flag_provider
    else
        set provider (_ai_config_read provider; or echo ollama)
    end

    # Resolve lang
    set -l lang en
    if set -q _flag_lang
        set lang $_flag_lang
    end

    # Load template
    set -l template_file ~/.config/fish/prompts/meta-commit.md
    set -l prompt
    if test -f $template_file
        set prompt (cat $template_file)
    else
        set prompt "Generate a concise git commit message for these changes. Use conventional commit format. First line max 72 chars, imperative mood. Output ONLY the commit message."
    end

    # Language instruction
    set -l lang_full (_ai_lang_name $lang)
    set prompt "IMPORTANT: Write the commit message in $lang_full.

$prompt

Diff:
$diff"

    # Run
    set -l model_flag
    if set -q _flag_model
        set model_flag --model $_flag_model
    end

    set -l output $_flag_output

    if test -n "$output"
        echo "$prompt" | _ai_provider_run --provider $provider $model_flag >$output
        set_color green
        echo "Saved to: $output"
        set_color normal
    else
        echo "$prompt" | _ai_provider_run --provider $provider $model_flag
    end
end
