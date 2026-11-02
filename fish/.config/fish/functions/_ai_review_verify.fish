function _ai_review_verify --description "Second-opinion verify pass over first-pass review findings"
    # Runs entirely through _ai_run. Whether the verifier can read the repo is a
    # matter of the mode (--agentic → read-only tools), not of the provider: by
    # default every executor reasons from the embedded code alone.
    #   --provider P  --model M  --workdir DIR  --lang FULL
    #   --findings-file F   first-pass output to verify (required)
    #   --code-file F       code/diff context embedded for the verifier (optional)
    #   --output F          write verdicts to a real file (avoids /dev/stdout loss)
    #   --lens A,B          the review's lenses, as knowledge to judge the findings by
    argparse 'provider=' 'model=' 'workdir=' 'lang=' 'findings-file=' 'code-file=' 'output=' 'lens=' 'agentic' 'no-think' 'dry-run' 'label=' 'dest=' -- $argv; or return 1

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

    # Watched run when writing to a file with a label (shows live progress);
    # otherwise a plain run (streaming / dry-run).
    if test -n "$_flag_output"; and test -n "$_flag_label"; and not set -q _flag_dry_run
        printf '%s' "$payload" | _ai_run_watched --label $_flag_label --output $_flag_output --dest $_flag_dest -- $run_args
    else
        test -n "$_flag_output"; and set -a run_args --output $_flag_output
        set -q _flag_dry_run; and set -a run_args --dry-run
        echo "$payload" | _ai_run $run_args
    end
end
