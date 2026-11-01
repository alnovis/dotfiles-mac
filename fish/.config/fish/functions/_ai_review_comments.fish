function _ai_review_comments --description "Third review stage: line comments for a merge request from the verified findings (<base>.comments.md + .json)"
    # Usage: _ai_review_comments --findings REVIEW --verdicts VERIFY --output REVIEW_OUT
    #          --provider P [--model M] [--lang FULL] [--range BASE..HEAD] [--root DIR] [--label L] [--dry-run]
    # The model only turns [CONFIRMED] / [UNCERTAIN] findings into comments with a quoted
    # line; _ai_review_comments_anchor then finds each line in the code itself. Nothing is
    # posted: the .md is for a human to check, the .json is shaped for GitLab and GitHub.
    argparse 'findings=' 'verdicts=' 'output=' 'provider=' 'model=' 'lang=' 'range=' 'root=' 'label=' 'dry-run' -- $argv; or return 1

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

    _ai_review_comments_anchor $arr "$_flag_range" $root >$json
    rm -f $arr
    _ai_review_comments_md $json >$md

    set -l n (jq '.comments | length' $json)
    set -l off (jq '[.comments[] | select(.anchored and (.in_diff | not))] | length' $json)
    set -l lost (jq '[.comments[] | select(.anchored | not)] | length' $json)
    set_color green
    echo "Comments saved to: $md ($n; not in the diff: $off, unanchored: $lost)"
    echo "              and: $json"
    set_color normal
end

function _ai_comments_output_path --description "review.md + EXT → review.comments.EXT" --argument-names out ext
    set -l dir (path dirname -- $out)
    set -l base (path basename -- $out | string replace -r '\.[^.]+$' '')
    echo $dir/$base.comments.$ext
end

function _ai_review_comments_md --description "The comments JSON as markdown for a human to check before publishing" --argument-names json
    jq -r '
        def where: if .anchored then "\(.path):\(.line) (\(.side))" else "\(.path) (line \(.line_cited // "?") cited, not found)" end;
        def notes:
            (if (.anchored | not) then "> Unanchored: the quoted line was not found in the code — check it by hand."
             elif .anchored_by == "line" then "> Placed by the cited line number: the quote did not match the code (model quoted: `\(.quote)`) — check this is the right line."
             else empty end),
            (if .anchored and (.in_diff | not) then "> Not in the diff: GitLab/GitHub take a line comment only inside the changes — post it as a general comment." else empty end);
        "# Review comments — check before publishing",
        "",
        "\(.comments | length) comment(s): \([.comments[] | select(.status == "confirmed")] | length) confirmed, \([.comments[] | select(.status != "confirmed")] | length) uncertain."
            + (if .base_sha then " Range: \(.base_sha[0:7])..\(.head_sha[0:7])." else "" end),
        "",
        (.comments | group_by(.path)[] |
            "## \(.[0].path)", "",
            (.[] |
                "### \(where) · \(.severity)" + (if .status == "confirmed" then "" else " · uncertain — needs a human check" end),
                "",
                "```",
                (.code // .quote),
                "```",
                "",
                .body,
                "",
                notes,
                ""))' $json
end
