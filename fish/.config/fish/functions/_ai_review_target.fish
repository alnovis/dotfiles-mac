function _ai_review_target --description "AI review of a project directory or single file (state-based, no git)"
    # Called by _ai_review dispatcher after mode detection.
    argparse 'h/help' 'provider=' 'model=' 'lang=' 'o/output=' 'with-project-context' 'lens=' 'no-lens' 'brief' 'dry-run' 'agentic' 'no-think' 'context-lines=' \
             'verify' 'no-verify' 'verify-provider=' 'verify-model=' 'verify-output=' 'verify-runs=' 'verify-context=' 'verify-think=' 'comments' 'runs=' 'parallel' 'no-parallel' -- $argv; or return 1
    # Lenses: --lens, else review_lens from the project's (or the global) config; --no-lens: none
    if set -q _flag_lens; and set -q _flag_no_lens
        echo "Error: --lens and --no-lens exclude each other" >&2
        return 1
    end
    set -l lens_origin --lens
    set -l lc (_ai_review_lens_choice "$_flag_lens" "$(set -q _flag_no_lens; and echo 1)" | string split \t)
    if test -n "$lc[1]"
        set _flag_lens $lc[1]
        set lens_origin $lc[2]
    end
    # Quoted: an empty (…) would vanish and shift the arguments
    _ai_review_comments_check "$(set -q _flag_comments; and echo 1)" "$(set -q _flag_brief; and echo 1)" \
        "$(set -q _flag_no_verify; and echo 1)" "$_flag_output"; or return 1

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

    # How many review runs, and how they go (scoped config, see _ai_review_setting)
    set -l plan_model $_flag_model
    test -n "$plan_model"; or set plan_model (_ai_default_model review $provider)
    set -l plan (_ai_review_runs_plan $provider "$plan_model" "$_flag_runs" "$(set -q _flag_parallel; and echo 1)" \
        "$(set -q _flag_no_parallel; and echo 1)" "$(set -q _flag_brief; and echo 1)" "$(set -q _flag_no_verify; and echo 1)")
    or return 1
    set plan (string split \t -- $plan)
    set -l runs $plan[1]

    set -l lang en
    if set -q _flag_lang
        set lang $_flag_lang
    end

    # Load prompt template (--brief: short fixed prompt instead, like git mode)
    set -l template_file ~/.config/fish/prompts/meta-review.md
    set -l prompt
    if set -q _flag_brief
        set -l subject "project"
        test -n "$target_file"; and set subject "file"
        set prompt "Give a brief summary of this $subject in 3-5 bullet points: what it does, how it is structured, and the main risks or problems. Be concise."
    else if test -f $template_file
        set prompt (_ai_review_template $template_file (_ai_review_prompt_mode $provider))
    else
        set prompt "Review this project. Analyze architecture, code quality, potential issues, and suggest improvements."
    end

    if test -n "$custom_prompt"
        set prompt "$prompt

Additional instructions: $custom_prompt"
    end

    # Security lens(es) — not applied to a brief summary
    if set -q _flag_lens; and not set -q _flag_brief
        # Validated outside (…): stderr there skips the caller's redirect
        _ai_review_lens $_flag_lens >/dev/null; or return 1
        set -l lens_block (_ai_review_lens $_flag_lens | string collect)
        set prompt "$prompt

$lens_block"
    end

    # Language instruction
    set -l lang_full (_ai_lang_name $lang)
    set prompt "IMPORTANT: Write your entire response in $lang_full.

$prompt"

    # Header: the same blocks as the stages and the Saved list (_ai_ui_heading, _ai_ui_kv)
    if test -n "$target_file"
        _ai_ui_heading Review "file $target_file"
    else
        _ai_ui_heading Review "project "(basename $target_dir)
    end
    _ai_ui_kv provider $provider
    set -q _flag_model; and _ai_ui_kv model $_flag_model
    _ai_ui_kv language $lang_full
    if set -q _flag_lens
        if set -q _flag_brief
            set_color yellow
            _ai_ui_kv lens "$_flag_lens (ignored — --brief mode)"
            set_color normal
        else
            set -l from ""
            test "$lens_origin" != --lens; and set from " ($lens_origin)"
            _ai_ui_kv lens "$_flag_lens$from"
        end
    end
    if _ai_verify_wanted "$(begin; set -q _flag_verify; or set -q _flag_comments; or set -q _flag_verify_runs; or set -q _flag_verify_context; or test $runs -gt 1; end; and echo 1)" "$(set -q _flag_no_verify; and echo 1)"
        if set -q _flag_brief
            set_color yellow
            _ai_ui_kv verify "requested (ignored — --brief mode)"
            set_color normal
        else
            # As the verify flow resolves it: flag > config verify_provider > review provider
            set -l vp $_flag_verify_provider
            test -z "$vp"; and set vp (_ai_config_read verify_provider 2>/dev/null)
            test -z "$vp"; and set vp "$provider"
            _ai_ui_kv verify "on ($vp)"
            set -q _flag_comments; and _ai_ui_kv comments "on (line comments from the verdicts)"
            test $runs -gt 1; and _ai_ui_kv runs "$runs ($plan[3])"
        end
    end
    set -q _flag_output; and _ai_ui_kv output $_flag_output
    if test -n "$target_file"; and set -q _flag_with_project_context
        _ai_ui_kv context "the project too"
    end

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

    # What gets embedded is decided by the mode, never by the provider (docs/refactoring.md §6):
    # by default the file, tree and README for every executor; with --agentic only the target
    # file — the executor explores the rest read-only. Embedded content is a floor, not a ceiling.
    set -l context ""

    if test -n "$target_file"
        set -l file_basename (basename $target_file)
        set -l file_ext
        if string match -q '*.*' -- $file_basename
            set file_ext (string match -r '[^.]+$' -- $file_basename)
        end
        set -l file_content (cat $target_file | string collect)
        set -l scope_note "Review ONLY this single file. Do not explore neighboring files."
        if set -q _flag_with_project_context
            set scope_note "Review this file. You may briefly consult neighboring files in the parent project for context if needed."
        end
        set -l fence (_ai_md_fence "$file_content")
        set context "$scope_note

## File: $file_basename
$fence$file_ext
$file_content
$fence
"
    end

    # Project tree + README: dir targets, and file targets with --with-project-context
    if not set -q _flag_agentic; and begin
            test -z "$target_file"; or set -q _flag_with_project_context
        end
        set -l tree_output (tree -a -L 4 --noreport -I 'node_modules|target|.git|.idea|__pycache__|.scala-build|.bsp|.metals|dist|build|out|.cache|.DS_Store' $work_dir 2>/dev/null | string collect)
        if test -n "$tree_output"
            set context "$context
## Project structure
```
$tree_output
```
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

    # A directory target embeds its files, within a line budget — without them a single-shot
    # model sees only the tree. The same block is the verify pass's code (files_block).
    set -l files_block ""
    if test -n "$target_dir"; and not set -q _flag_agentic; and not set -q _flag_brief
        set -l budget (_ai_review_context_budget dir $_flag_context_lines); or return 1
        if test $budget -gt 0
            set -l files
            set -l window 0
            for row in (_ai_review_dir_files $target_dir)
                set -l parts (string split \t -- $row)
                set window (math $window + $parts[1])
                set -a files $parts[2]
            end
            if test (count $files) -gt 0
                _ai_ui_kv files "$window lines across "(count $files)" files (budget $budget)" >&2
                set -l embed 0
                if test $window -le $budget
                    set embed 1
                else if isatty stdin; and isatty stderr
                    set_color yellow >&2
                    echo "The directory's files ($window lines) exceed the budget ($budget)." >&2
                    echo "  [1] tree only (default)    [2] embed all $window lines" >&2
                    set_color normal >&2
                    read -l -P "Choose [1/2]: " choice
                    test "$choice" = 2; and set embed 1
                else
                    set_color yellow >&2
                    _ai_ui_kv note "the directory's files ($window lines) exceed the budget ($budget) — tree only. Pass --context-lines $window (or set config key dir_context_lines) to embed all." >&2
                    set_color normal >&2
                end
                if test $embed -eq 1
                    set files_block (_ai_review_files_block $target_dir $files | string collect)
                    set context "$context
$files_block"
                end
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

    # Verify runs only for the detailed (non-brief) review.
    set -l do_verify 0
    if not set -q _flag_brief; and _ai_verify_wanted "$(begin; set -q _flag_verify; or set -q _flag_comments; or set -q _flag_verify_runs; or set -q _flag_verify_context; or test $runs -gt 1; end; and echo 1)" "$(set -q _flag_no_verify; and echo 1)"
        set do_verify 1
        set -l p1file (mktemp)
        printf '%s' "$full_prompt" >$p1file
        set -l flow_args --prompt-file $p1file --provider $provider --workdir $work_dir --lang $lang_full
        # No range here: comments are anchored in the working tree, and none is in a diff
        set -q _flag_comments; and set -a flow_args --comments
        set -a flow_args --runs $runs --parallel-mode $plan[2]
        test -n "$model"; and set -a flow_args --model $model
        test -n "$output"; and set -a flow_args --output $output
        set -q _flag_dry_run; and set -a flow_args --dry-run
        set -q _flag_verify_provider; and set -a flow_args --verify-provider $_flag_verify_provider
        set -q _flag_verify_model; and set -a flow_args --verify-model $_flag_verify_model
        set -q _flag_verify_output; and set -a flow_args --verify-output $_flag_verify_output
        set -q _flag_verify_runs; and set -a flow_args --verify-runs $_flag_verify_runs
        set -q _flag_verify_context; and set -a flow_args --verify-context $_flag_verify_context
        set -q _flag_verify_think; and set -a flow_args --verify-think $_flag_verify_think
        set -q _flag_lens; and set -a flow_args --lens $_flag_lens
        set -q _flag_agentic; and set -a flow_args --agentic
        set -q _flag_no_think; and set -a flow_args --no-think
        # The verifier gets the code pass 1 saw: the target file, or the directory's files.
        set -l code_tmp
        if test -n "$target_file"
            set -a flow_args --code-file $target_file
        else if test -n "$files_block"
            set code_tmp (mktemp)
            printf '%s' "$files_block" >$code_tmp
            set -a flow_args --code-file $code_tmp
        end
        _ai_review_verify_flow $flow_args
        rm -f $p1file $code_tmp
    else if test -n "$output"; and not set -q _flag_dry_run
        # Output captured to a file → terminal is quiet, so show a live watched run.
        set -l lbl "Review - $provider"
        test -n "$model"; and set lbl "$lbl - $model"
        _ai_stage_plan "$lbl"
        set -l runner_args --provider $provider --workdir $work_dir $model_flag
        set -q _flag_agentic; and set -a runner_args --agentic --skill ai-review
        set -q _flag_no_think; and set -a runner_args --no-think
        echo "$full_prompt" | _ai_run_watched --heading --label "[1/1] $lbl" --output $output --dest $output -- $runner_args
    else
        # Streaming to terminal (or dry-run): output is visible, no spinner needed.
        set -l runner_args --provider $provider --workdir $work_dir $model_flag
        set -q _flag_dry_run; and set -a runner_args --dry-run
        set -q _flag_agentic; and set -a runner_args --agentic --skill ai-review
        set -q _flag_no_think; and set -a runner_args --no-think
        set -l t0 (date +%s)
        echo "$full_prompt" | _ai_run $runner_args
        set -q _flag_dry_run; or printf '\n  done | %ds\n' (math (date +%s) - $t0) >&2
    end

    # Verify mode reports its own two files (review + verify) inside the flow; only
    # the single-file (non-verify) path reports here.
    if test $do_verify -eq 0; and test -n "$output"; and not set -q _flag_dry_run
        if test -s "$output"
            _ai_ui_heading Saved
            _ai_ui_kv review $output
        else
            set_color red
            echo "No output written — $output is empty. The model returned nothing (interrupted stream, or context/size issue). Try again, or --context-lines 0 for a smaller prompt." >&2
            set_color normal
            return 1
        end
    end
end
