function _ai_review_comments --description "Third review stage: line comments for a merge request from the verified findings (<base>.comments.md + .json)"
    # Usage: _ai_review_comments --findings REVIEW --verdicts VERIFY --output REVIEW_OUT
    #          --provider P [--model M] [--lang FULL] [--range BASE..HEAD] [--root DIR] [--label L] [--dry-run]
    # The model only turns [CONFIRMED] / [UNCERTAIN] findings into comments with a quoted
    # line; _ai_review_comments_anchor then finds each line in the code itself. Nothing is
    # posted: the .md is for a human to check, the .json is shaped for GitLab and GitHub.
    # --quiet: no "saved to" lines — the caller lists every file of the run at the end
    # --runs N: how many review runs answered — each comment's "seen" is out of N
    argparse 'findings=' 'verdicts=' 'output=' 'provider=' 'model=' 'lang=' 'range=' 'root=' 'label=' 'dry-run' 'quiet' 'runs=' -- $argv; or return 1
    set -l runs $_flag_runs
    test -n "$runs"; or set runs 1

    set -l md (_ai_comments_output_path $_flag_output md)
    set -l json (_ai_comments_output_path $_flag_output json)
    set -l root $_flag_root
    test -n "$root"; or set root $PWD

    if set -q _flag_dry_run
        echo "comments provider=$_flag_provider model=$_flag_model (prompt: meta-comments.md + review + verdicts; lines anchored by git"(test -n "$_flag_range"; and echo " in $_flag_range")")" >&2
        echo "would write: comments -> $md ; $json" >&2
        return 0
    end
    if not test -s "$_flag_findings"; or not test -s "$_flag_verdicts"
        echo "comments: needs the review and its verify verdicts" >&2
        return 1
    end

    set -l prompt (cat ~/.config/fish/prompts/meta-comments.md | string collect)
    test -n "$_flag_lang"; and test "$_flag_lang" != English
    and set prompt "IMPORTANT: Write the comment bodies (\"body\") in $_flag_lang; keep code, identifiers and quotes as they are.

$prompt"
    set prompt "$prompt

REVIEW FINDINGS:
"(cat $_flag_findings | string collect)"

VERDICTS ON THEM:
"(cat $_flag_verdicts | string collect)

    set -l run_args --provider $_flag_provider
    test -n "$_flag_model"; and set -a run_args --model $_flag_model
    set -l label $_flag_label
    test -n "$label"; or set label "Comments - $_flag_provider"
    set -l raw (mktemp)
    printf '%s' "$prompt" | _ai_run_watched --label $label --output $raw --dest "(terminal)" -- $run_args
    or begin
        rm -f $raw
        return 1
    end

    # The JSON array: inside the ```json fence, else from the first [ to the last ]
    set -l arr (mktemp)
    awk '/^```json/ { f = 1; next } /^```/ { if (f) exit } f' $raw >$arr
    if not jq -e 'type == "array"' $arr >/dev/null 2>&1
        string collect <$raw | string replace -r -- '(?s)^[^\[]*' '' | string replace -r -- '(?s)\][^\]]*$' ']' >$arr
    end
    if not jq -e 'type == "array"' $arr >/dev/null 2>&1
        set -l kept (_ai_comments_output_path $_flag_output raw.txt)
        mv $raw $kept
        rm -f $arr
        echo "comments: the model's answer is not a JSON array — kept as $kept" >&2
        return 1
    end
    rm -f $raw

    _ai_review_comments_anchor $arr "$_flag_range" $root $runs >$json
    rm -f $arr
    _ai_review_comments_md $json >$md

    set -q _flag_quiet; and return 0
    set_color green
    _ai_review_comments_saved $_flag_output $_flag_verdicts
    set_color normal
end

function _ai_review_comments_saved --description "The 'saved to' lines of the comments of REVIEW_OUT, with their counts; VERDICTS explains an empty set" --argument-names out verdicts
    set -l md (_ai_comments_output_path $out md)
    set -l json (_ai_comments_output_path $out json)
    test -s $json; or return 1
    set -l n (jq '.comments | length' $json)
    # None is a result, not a failure: verify confirmed nothing. Say so instead of "(0; …)".
    # The empty JSON is still written — a publishing tool reads an empty array fine.
    if test $n -eq 0
        set -l why "the verify pass confirmed no finding"
        set -l refuted (string match -r -g '(\d+) refuted' <$verdicts 2>/dev/null | tail -1)
        test -n "$refuted"; and set why "$why ($refuted refuted)"
        echo "Comments:          none — $why"
        return 0
    end
    # Only the counts that are not zero: general = not in the diff or file-level
    set -l general (jq '[.comments[] | select((.anchored and (.in_diff | not)) or .file_level)] | length' $json)
    set -l lost (jq '[.comments[] | select((.anchored | not) and (.file_level | not))] | length' $json)
    set -l parts "$n"
    test $general -gt 0; and set -a parts "$general as general comments"
    test $lost -gt 0; and set -a parts "$lost unanchored"
    echo "Comments saved to: $md ("(string join ', ' -- $parts)")"
    echo "                   $json"
end

function _ai_comments_output_path --description "review.md + EXT → review.comments.EXT" --argument-names out ext
    set -l dir (path dirname -- $out)
    set -l base (path basename -- $out | string replace -r '\.[^.]+$' '')
    echo $dir/$base.comments.$ext
end

function _ai_review_comments_md --description "The comments JSON as markdown for a human to check before publishing" --argument-names json
    jq -r '
        # The file is the section heading; a comment heading names only its line
        def where:
            if .anchored then "Line \(.line) (\(.side))"
            elif .file_level then "Whole file"
            else "Line \(.line_cited // "?") cited, not found" end;
        def found_by: if (.runs // 1) > 1 then " · found by \(.seen) of \(.runs) runs" else "" end;
        def notes:
            (if .file_level then "> File-level: no line to attach it to — post it as a general comment."
             elif (.anchored | not) then "> Unanchored: the quoted line was not found in the code — check it by hand."
             elif .anchored_by == "line" then "> Placed by the cited line number: the quote did not match the code (model quoted: `\(.quote)`) — check this is the right line."
             else empty end),
            (if .anchored and (.in_diff | not) then "> Not in the diff: GitLab/GitHub take a line comment only inside the changes — post it as a general comment." else empty end);
        "# Review comments — check before publishing",
        "",
        "\(.comments | length) comment(s): \([.comments[] | select(.status == "confirmed")] | length) confirmed, \([.comments[] | select(.status != "confirmed")] | length) uncertain."
            + (if .base_sha then " Range: \(.base_sha[0:7])..\(.head_sha[0:7])." else "" end)
            + (if (.runs // 1) > 1 then " From \(.runs) review runs." else "" end),
        "",
        (.comments | group_by(.path)[] |
            "## \(.[0].path)", "",
            (.[] |
                "### \(where) · \(.severity)" + (if .status == "confirmed" then "" else " · uncertain — needs a human check" end) + found_by,
                "",
                (if (.code // .quote) == "" then empty else
                    "```", ((.code // .quote) | sub("^[[:space:]]+"; "")), "```", "" end),
                .body,
                "",
                notes,
                ""))' $json
end
