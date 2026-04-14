function _ai_gen_review --description "AI project review using meta-prompt"
    argparse 'h/help' 'provider=' 'model=' 'l/lang=' 'o/output=' -- $argv; or return 1

    if set -q _flag_help
        echo "Usage: ai gen review [DIR] [OPTIONS] [\"custom prompt\"]"
        echo ""
        echo "Generate a project review using AI."
        echo "Default DIR: current directory."
        echo "Default prompt: ~/.config/fish/prompts/meta-review.md"
        echo ""
        echo "Options:"
        echo "  --provider PROVIDER   Override provider (ollama, claude)"
        echo "  --model MODEL         Override model"
        echo "  -l, --lang LANG       Response language (default: en)"
        echo "  -o, --output FILE     Save output to file (default: stdout)"
        echo "  -h, --help            Show this help"
        echo ""
        echo "Examples:"
        echo "  ai gen review                              Review current dir"
        echo "  ai gen review ~/work/project               Review specific dir"
        echo "  ai gen review --provider claude             Use Claude"
        echo "  ai gen review --lang ru -o review.md        Russian, save to file"
        echo "  ai gen review . \"focus on security\"         Custom prompt"
        return 0
    end

    # Resolve positional args: [DIR] ["custom prompt"]
    set -l dir
    set -l custom_prompt
    for arg in $argv
        if test -z "$dir"; and test -d "$arg"
            set dir $arg
        else
            set custom_prompt $arg
        end
    end

    if test -z "$dir"
        set dir .
    end
    set dir (realpath $dir)

    if not test -d "$dir"
        set_color red
        echo "Error: directory not found: $dir"
        set_color normal
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

    # Load prompt template
    set -l template_file ~/.config/fish/prompts/meta-review.md
    set -l prompt
    if test -f $template_file
        set prompt (cat $template_file)
    else
        set prompt "Review this project. Analyze architecture, code quality, potential issues, and suggest improvements."
    end

    if test -n "$custom_prompt"
        set prompt "$prompt

Additional instructions: $custom_prompt"
    end

    # Language instruction
    set -l lang_full (_ai_lang_name $lang)
    set prompt "IMPORTANT: Write your entire response in $lang_full.

$prompt"

    # Header
    set_color cyan
    echo "Project: "(basename $dir)
    set_color normal
    echo "Provider: $provider"
    if set -q _flag_model
        echo "Model: $_flag_model"
    end
    echo "Language: $lang_full"
    if set -q _flag_output
        echo "Output: $_flag_output"
    end
    echo "---"

    # Provider-specific execution
    set -l model_flag
    if set -q _flag_model
        set model_flag --model $_flag_model
    end

    set -l output $_flag_output

    switch $provider
        case claude
            if test -n "$output"
                cd $dir && claude -p $model_flag "$prompt" >$output
            else
                cd $dir && claude -p $model_flag "$prompt"
            end

        case ollama
            # Enrich prompt with project context (ollama has no file access)
            set -l context ""

            set -l tree_output (tree -L 3 --noreport -I 'node_modules|target|.git|.idea|__pycache__|.scala-build|.bsp|.metals|dist|build|out|.cache' $dir 2>/dev/null)
            if test -n "$tree_output"
                set context "$context
## Project structure
\`\`\`
$tree_output
\`\`\`
"
            end

            for f in $dir/README.md $dir/readme.md $dir/README.rst $dir/README
                if test -f $f
                    set -l readme_content (head -100 $f)
                    set context "$context
## README
$readme_content
"
                    break
                end
            end

            set -l full_prompt "$prompt

# Project context
Directory: $dir
$context"

            if test -n "$output"
                echo "$full_prompt" | _ai_provider_run --provider ollama $model_flag >$output
            else
                echo "$full_prompt" | _ai_provider_run --provider ollama $model_flag
            end

        case '*'
            set_color red
            echo "Unknown provider: $provider"
            set_color normal
            return 1
    end

    if test -n "$output"
        set_color green
        echo "Saved to: $output"
        set_color normal
    end
end
