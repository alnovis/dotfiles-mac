function _ai_gen_review --description "AI project/file review using meta-prompt"
    argparse 'h/help' 'provider=' 'model=' 'l/lang=' 'o/output=' 'with-project-context' -- $argv; or return 1

    if set -q _flag_help
        echo "Usage: ai gen review [DIR|FILE] [OPTIONS] [\"custom prompt\"]"
        echo ""
        echo "Generate a review of a project (directory) or a single file using AI."
        echo "Default target: current directory."
        echo "Default prompt: ~/.config/fish/prompts/meta-review.md"
        echo ""
        echo "Options:"
        echo "  --provider PROVIDER         Override provider (ollama, claude)"
        echo "  --model MODEL               Override model"
        echo "  -l, --lang LANG             Response language (default: en)"
        echo "  -o, --output FILE           Save output to file (default: stdout)"
        echo "  --with-project-context      For file targets, also include parent project context"
        echo "  -h, --help                  Show this help"
        echo ""
        echo "Examples:"
        echo "  ai gen review                                   Review current dir"
        echo "  ai gen review ~/work/project                    Review specific dir"
        echo "  ai gen review script.sh                         Review a single file"
        echo "  ai gen review script.sh --with-project-context  File plus parent project context"
        echo "  ai gen review --provider claude                 Use Claude"
        echo "  ai gen review --lang ru -o review.md            Russian, save to file"
        echo "  ai gen review . \"focus on security\"             Custom prompt"
        return 0
    end

    # Resolve positional args: [DIR|FILE] ["custom prompt"]
    set -l target_dir
    set -l target_file
    set -l custom_prompt
    for arg in $argv
        if test -z "$target_dir"; and test -z "$target_file"; and test -d "$arg"
            set target_dir $arg
        else if test -z "$target_dir"; and test -z "$target_file"; and test -f "$arg"
            set target_file $arg
        else
            set custom_prompt $arg
        end
    end

    if test -z "$target_dir"; and test -z "$target_file"
        set target_dir .
    end

    if test -n "$target_file"
        set target_file (realpath $target_file)
    else
        set target_dir (realpath $target_dir)
        if not test -d "$target_dir"
            set_color red
            echo "Error: directory not found: $target_dir"
            set_color normal
            return 1
        end
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
    if test -n "$target_file"
        echo "File: $target_file"
    else
        echo "Project: "(basename $target_dir)
    end
    set_color normal
    echo "Provider: $provider"
    if set -q _flag_model
        echo "Model: $_flag_model"
    end
    echo "Language: $lang_full"
    if set -q _flag_output
        echo "Output: $_flag_output"
    end
    if test -n "$target_file"; and set -q _flag_with_project_context
        echo "Project context: yes"
    end
    echo "---"

    # Provider-specific execution
    set -l model_flag
    if set -q _flag_model
        set model_flag --model $_flag_model
    end

    set -l output $_flag_output

    # Working dir for claude / base for optional project context
    set -l work_dir
    if test -n "$target_file"
        set work_dir (dirname $target_file)
    else
        set work_dir $target_dir
    end

    # File payload (content + lang hint), reused by both providers when target is a file
    set -l file_basename
    set -l file_ext
    set -l file_content
    if test -n "$target_file"
        set file_basename (basename $target_file)
        if string match -q '*.*' -- $file_basename
            set file_ext (string match -r '[^.]+$' -- $file_basename)
        end
        set file_content (cat $target_file | string collect)
    end

    switch $provider
        case claude
            if test -n "$target_file"
                set -l scope_note "Review ONLY this single file. Do not explore neighboring files."
                if set -q _flag_with_project_context
                    set scope_note "Review this file. You may briefly consult neighboring files in the parent project for context if needed."
                end
                set -l claude_prompt "Target file: $file_basename
$scope_note

## File contents
\`\`\`$file_ext
$file_content
\`\`\`

$prompt"
                if test -n "$output"
                    cd $work_dir && claude -p $model_flag "$claude_prompt" >$output
                else
                    cd $work_dir && claude -p $model_flag "$claude_prompt"
                end
            else
                if test -n "$output"
                    cd $target_dir && claude -p $model_flag "$prompt" >$output
                else
                    cd $target_dir && claude -p $model_flag "$prompt"
                end
            end

        case ollama
            # Enrich prompt with context (ollama has no file access)
            set -l context ""

            if test -n "$target_file"
                set context "$context
## File: $file_basename
\`\`\`$file_ext
$file_content
\`\`\`
"
            end

            # Project tree + README: always for dir targets, opt-in for file targets
            if test -z "$target_file"; or set -q _flag_with_project_context
                set -l tree_output (tree -L 3 --noreport -I 'node_modules|target|.git|.idea|__pycache__|.scala-build|.bsp|.metals|dist|build|out|.cache' $work_dir 2>/dev/null)
                if test -n "$tree_output"
                    set context "$context
## Project structure
\`\`\`
$tree_output
\`\`\`
"
                end

                for f in $work_dir/README.md $work_dir/readme.md $work_dir/README.rst $work_dir/README
                    if test -f $f
                        set -l readme_content (head -100 $f)
                        set context "$context
## README
$readme_content
"
                        break
                    end
                end
            end

            set -l full_prompt
            if test -n "$target_file"
                set full_prompt "$prompt

# File context
Path: $target_file
$context"
            else
                set full_prompt "$prompt

# Project context
Directory: $target_dir
$context"
            end

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
