function _ai_review_verify --description "Second-opinion verify pass over first-pass review findings"
    # Runs entirely through _ai_run. Whether the verifier can read the repo is a
    # matter of the mode (--agentic → read-only tools), not of the provider: by
    # default every executor reasons from the embedded code alone.
    #   --provider P  --model M  --workdir DIR  --lang FULL
    #   --findings-file F   first-pass output to verify (required)
    #   --code-file F       code/diff context embedded for the verifier (optional)
    #   --output F          write verdicts to a real file (avoids /dev/stdout loss)
    #   --lens A,B          the review's lenses, as knowledge to judge the findings by
    #   --runs N --mode M   N verify runs (parallel | sequential), joined by majority per
    #                       finding number (_ai_verify_vote); each run kept as <dest>.runK
    argparse 'provider=' 'model=' 'workdir=' 'lang=' 'findings-file=' 'code-file=' 'output=' 'lens=' 'runs=' 'mode=' 'agentic' 'no-think' 'dry-run' 'label=' 'dest=' -- $argv; or return 1

    set -l provider $_flag_provider
    test -z "$provider"; and set provider ollama
    set -l model $_flag_model
    set -l workdir $_flag_workdir
    test -z "$workdir"; and set workdir $PWD
    set -l lang $_flag_lang

    if test -z "$_flag_findings_file"; or not test -f "$_flag_findings_file"
        echo "verify: no first-pass findings to verify" >&2
        return 1
    end
    # Numbered here too, for a review saved before numbering (--verify-only); already
    # numbered findings pass through unchanged
    set -l findings (_ai_review_number_findings <$_flag_findings_file | string collect)

    # Verify system prompt (overridable).
    set -l vfile ~/.config/fish/prompts/meta-verify.md
    set -l vprompt
    if test -f $vfile
        set vprompt (cat $vfile | string collect)
    else
        set vprompt "You are a second-opinion reviewer. Assume each finding below is wrong until confirmed in the source. For each finding, write one line keyed to it with exactly one verdict — [CONFIRMED N/10], [REFUTED N/10] or [UNCERTAIN] (N = your confidence digit) — then a 'why:' line citing what you found in the code. Do not add new findings. End with: Verify: X confirmed, Y refuted, Z uncertain"
    end

    set -l lang_prefix ""
    test -n "$lang"; and set lang_prefix "IMPORTANT: Write your response in $lang."\n\n

    set -l payload "$lang_prefix$vprompt"
    # The review's lenses: what a misread of the language or library looks like
    if test -n "$_flag_lens"
        # Validated outside a command substitution: stderr inside (…) skips the caller's
        # redirect, so an unknown-lens error would bypass 2>file / | tee
        _ai_review_lens --verify $_flag_lens >/dev/null; or return 1
        set -l lens_block (_ai_review_lens --verify $_flag_lens | string collect)
        set payload "$payload

$lens_block"
    end
    set payload "$payload

FINDINGS FROM THE FIRST PASS (verify each):
$findings"

    # Embed the code the first pass saw. With --agentic the verifier may also explore
    # beyond it; otherwise it reasons from this alone.
    if test -n "$_flag_code_file"; and test -f "$_flag_code_file"
        set -l code (cat $_flag_code_file | string collect)
        set payload "$payload

CODE UNDER REVIEW (the first pass saw this):
$code"
    end

    set -l run_args --provider $provider --workdir $workdir
    test -n "$model"; and set -a run_args --model $model
    set -q _flag_agentic; and set -a run_args --agentic --skill ai-verify
    set -q _flag_no_think; and set -a run_args --no-think

    # Several runs: the same payload N times, then a majority vote per finding number
    set -l runs $_flag_runs
    test -n "$runs"; or set runs 1
    if test $runs -gt 1; and test -n "$_flag_output"; and test -n "$_flag_label"; and not set -q _flag_dry_run
        set -l pfile (mktemp)
        printf '%s' "$payload" >$pfile
        # The run files sit next to the verify file (<dest>.runK); to the terminal, next to
        # the temporary output, removed after the vote
        set -l dest $_flag_dest
        set -l dest_is_temp 0
        if test -z "$dest"; or test "$dest" = "(terminal)"
            set dest $_flag_output
            set dest_is_temp 1
        end
        set -l mode $_flag_mode
        test -n "$mode"; or set mode sequential
        set -l joined (mktemp)
        set -g __ai_review_runs_ok 0
        _ai_review_runs --runs $runs --mode $mode --prompt-file $pfile --output $joined --dest $dest --label $_flag_label -- $run_args
        set -l rc $status
        rm -f $pfile $joined
        set -l dir (path dirname -- $dest)
        set -l base (path basename -- $dest | string replace -r '\.[^.]+$' '')
        set -l ext (path extension -- $dest)
        set -l files (path filter -f -- $dir/$base.run(seq $runs)$ext)
        if test $rc -ne 0; or test (count $files) -eq 0
            set -g __ai_last_failure "no verify run answered"
            : >$_flag_output
            return 1
        end
        # A run that did not answer counts as "not judged" for every finding: the majority
        # stays out of N, so two of three runs failing leaves everything UNCERTAIN
        _ai_verify_vote $runs $files >$_flag_output
        test $dest_is_temp -eq 1; and rm -f $files
        set -g __ai_verify_run_files $files
        test $dest_is_temp -eq 1; and set -e __ai_verify_run_files
        return 0
    end

    # Watched run when writing to a file with a label (shows live progress);
    # otherwise a plain run (streaming / dry-run).
    if test -n "$_flag_output"; and test -n "$_flag_label"; and not set -q _flag_dry_run
        printf '%s' "$payload" | _ai_run_watched --heading --label $_flag_label --output $_flag_output --dest $_flag_dest -- $run_args
    else
        test -n "$_flag_output"; and set -a run_args --output $_flag_output
        set -q _flag_dry_run; and set -a run_args --dry-run
        echo "$payload" | _ai_run $run_args
    end
end
