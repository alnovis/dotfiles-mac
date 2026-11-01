function _ai_review_comments_check --description "Refuse --comments where it cannot work: args COMMENTS BRIEF NO_VERIFY OUTPUT (flag presence as 1 or empty)" --argument-names comments brief no_verify output
    test -n "$comments"; or return 0
    set -l why
    if test -n "$brief"
        set why "--comments works on a full review, not --brief"
    else if test -n "$no_verify"
        set why "--comments is built from the verify verdicts — drop --no-verify"
    else if test -z "$output"
        set why "--comments writes files next to the report — give -o FILE"
    end
    test -z "$why"; and return 0
    set_color red >&2
    echo "Error: $why" >&2
    set_color normal >&2
    return 1
end
