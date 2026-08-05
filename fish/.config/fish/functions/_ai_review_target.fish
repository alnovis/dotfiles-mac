function _ai_review_target --description "AI review of a project directory or single file (state-based, no git)"
    # Called by _ai_review dispatcher after mode detection.
    argparse 'h/help' 'provider=' 'model=' 'l/lang=' 'o/output=' 'with-project-context' 'lens=' 'dry-run' 'agentic' \
             'verify' 'no-verify' 'verify-provider=' 'verify-model=' 'verify-output=' -- $argv; or return 1

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

    set -l provider
    if set -q _flag_provider
        set provider $_flag_provider
    else
        set provider (_ai_default_provider review)
    end

    set -l lang en
    if set -q _flag_lang
        set lang $_flag_lang
    end

    # Load prompt template
    set -l template_file ~/.config/fish/prompts/meta-review.md
    set -l prompt
    if test -f $template_file
        set prompt (cat $template_file | string collect)
    else
        set prompt "Review this project. Analyze architecture, code quality, potential issues, and suggest improvements."
    end

    if test -n "$custom_prompt"
        set prompt "$prompt

Additional instructions: $custom_prompt"
    end

    # Security lens(es)
    if set -q _flag_lens
        set -l lens_block (_ai_review_lens $_flag_lens | string collect)
        test $pipestatus[1] -eq 0; or return 1
        set prompt "$prompt

$lens_block"
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
    if set -q _flag_lens
        echo "Lens: $_flag_lens"
    end
    if _ai_verify_wanted (set -q _flag_verify; and echo 1) (set -q _flag_no_verify; and echo 1)
        set -l vp $_flag_verify_provider
        test -z "$vp"; and set vp "$provider"
        echo "Verify: on ($vp)"
    end
    if set -q _flag_output
        echo "Output: $_flag_output"
    end
    if test -n "$target_file"; and set -q _flag_with_project_context
        echo "Project context: yes"
    end
    echo "---"

    set -l model $_flag_model
    if test -z "$model"
        set model (_ai_default_model review $provider)
    end
    set -l model_flag
    if test -n "$model"
        set model_flag --model $model
    end

    set -l output $_flag_output

    # Working dir: parent dir for file targets, the dir itself otherwise
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

    # Build provider-specific prompt. Claude reads files via workdir cd; ollama needs context embedded.
    set -l full_prompt
    switch $provider
        case claude
            if test -n "$target_file"
                set -l scope_note "Review ONLY this single file. Do not explore neighboring files."
                if set -q _flag_with_project_context
                    set scope_note "Review this file. You may briefly consult neighboring files in the parent project for context if needed."
                end
                set full_prompt "Target file: $file_basename
$scope_note

## File contents
\`\`\`$file_ext
$file_content
\`\`\`

$prompt"
            else
                set full_prompt $prompt
            end

        case ollama
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
                set -l tree_output (tree -a -L 4 --noreport -I 'node_modules|target|.git|.idea|__pycache__|.scala-build|.bsp|.metals|dist|build|out|.cache|.DS_Store' $work_dir 2>/dev/null | string collect)
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
                        set -l readme_content (head -100 $f | string collect)
                        set context "$context
## README
$readme_content
"
                        break
                    end
                end
            end

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

        case '*'
            set_color red
            echo "Unknown provider: $provider"
            set_color normal
            return 1
    end

    set -l do_verify 0
    if _ai_verify_wanted (set -q _flag_verify; and echo 1) (set -q _flag_no_verify; and echo 1)
        set do_verify 1
        set -l p1file (mktemp)
        printf '%s' "$full_prompt" >$p1file
        set -l flow_args --prompt-file $p1file --provider $provider --workdir $work_dir --lang $lang_full
        test -n "$model"; and set -a flow_args --model $model
        test -n "$output"; and set -a flow_args --output $output
        set -q _flag_dry_run; and set -a flow_args --dry-run
        set -q _flag_verify_provider; and set -a flow_args --verify-provider $_flag_verify_provider
        set -q _flag_verify_model; and set -a flow_args --verify-model $_flag_verify_model
        set -q _flag_verify_output; and set -a flow_args --verify-output $_flag_verify_output
        set -q _flag_agentic; and set -a flow_args --agentic
        # A single-file target is the code context embedded for the verifier.
        test -n "$target_file"; and set -a flow_args --code-file $target_file
        _ai_review_verify_flow $flow_args
        rm -f $p1file
    else if test -n "$output"; and not set -q _flag_dry_run
        # Output captured to a file → terminal is quiet, so show a live watched run.
        set -l lbl "Review - $provider"
        test -n "$model"; and set lbl "$lbl - $model"
        _ai_stage_plan "$lbl"
        set -l runner_args --provider $provider --workdir $work_dir $model_flag
        set -q _flag_agentic; and set -a runner_args --agentic
        echo "$full_prompt" | _ai_run_watched --label "$lbl" --output $output --dest $output -- $runner_args
    else
        # Streaming to terminal (or dry-run): output is visible, no spinner needed.
        set -l runner_args --provider $provider --workdir $work_dir $model_flag
        set -q _flag_dry_run; and set -a runner_args --dry-run
        set -q _flag_agentic; and set -a runner_args --agentic
        echo "$full_prompt" | _ai_run $runner_args
    end

    # Verify mode reports its own two files (review + verify) inside the flow; only
    # the single-file (non-verify) path reports here.
    if test $do_verify -eq 0; and test -n "$output"; and not set -q _flag_dry_run
        if test -s "$output"
            set_color green
            echo "Saved to: $output"
            set_color normal
        else
            set_color red
            echo "No output written — $output is empty. The model returned nothing (interrupted stream, or context/size issue). Try again, or --context-lines 0 for a smaller prompt." >&2
            set_color normal
            return 1
        end
    end
end
