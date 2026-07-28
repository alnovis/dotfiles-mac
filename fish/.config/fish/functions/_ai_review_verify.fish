function _ai_review_verify --description "Second-opinion verify pass over first-pass review findings"
    # Runs entirely through the provider abstraction (_ai_run) — no agent-runner
    # coupling. The claude provider (claude -p) is agentic and reads the repo
    # itself; ollama reasons from the embedded code. Tool grounding is a property
    # of the provider, not of this function. (Agentic local verify, if ever wanted,
    # belongs to a proper agent-runner abstraction — see the `ai agent` roadmap —
    # not a pi special-case wired into review.)
    #   --provider P  --model M  --workdir DIR  --lang FULL
    #   --findings-file F   first-pass output to verify (required)
    #   --code-file F       code/diff context embedded for the verifier (optional)
    #   --output F          write verdicts to a real file (avoids /dev/stdout loss)
    argparse 'provider=' 'model=' 'workdir=' 'lang=' 'findings-file=' 'code-file=' 'output=' 'agentic' 'dry-run' 'label=' 'dest=' -- $argv; or return 1

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
    set -l findings (cat $_flag_findings_file | string collect)

    # Verify system prompt (overridable).
    set -l vfile ~/.config/fish/prompts/meta-verify.md
    set -l vprompt
    if test -f $vfile
        set vprompt (cat $vfile | string collect)
    else
        set vprompt "You are a second-opinion reviewer. Assume each finding below is wrong until confirmed in the source. For each, output a verdict: [CONFIRMED N/10] | [REFUTED N/10 — reason] | [UNCERTAIN — what's missing], keyed to the finding. Do not add new findings."
    end

    set -l lang_prefix ""
    test -n "$lang"; and set lang_prefix "IMPORTANT: Write your response in $lang."\n\n

    set -l payload "$lang_prefix$vprompt

FINDINGS FROM THE FIRST PASS (verify each):
$findings"

    # Embed the code the first pass saw. A tool-capable provider (claude) can also
    # explore beyond it; a plain one (ollama) reasons from this alone.
    if test -n "$_flag_code_file"; and test -f "$_flag_code_file"
        set -l code (cat $_flag_code_file | string collect)
        set payload "$payload

CODE UNDER REVIEW (the first pass saw this):
$code"
    end

    set -l run_args --provider $provider --workdir $workdir
    test -n "$model"; and set -a run_args --model $model
    set -q _flag_agentic; and set -a run_args --agentic

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
