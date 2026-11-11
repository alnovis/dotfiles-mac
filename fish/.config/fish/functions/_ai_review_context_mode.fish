function _ai_review_context_mode --description "What the review pass sees, for PROVIDER/MODEL: --context FLAG (or --agentic) > review_context (scoped) > embedded; prints mode<TAB>origin" --argument-names provider model flag agentic
    # embedded  the diff and the changed files within --context-lines (git), the file, tree,
    #           README or the directory's files (target); no tools
    # agentic   the minimum, read-only tools and the ai-review skill; the model reads the rest
    # --agentic is --context agentic, kept for the commands that use it. The verify pass
    # follows the mode found here unless --verify-context says otherwise (_ai_verify_context_mode).
    # AGENTIC is "1" when --agentic was given.
    if test "$agentic" = 1; and test -n "$flag"; and test "$flag" != agentic
        echo "Error: --agentic is --context agentic, and --context says $flag" >&2
        return 1
    end
    set -l mode
    set -l origin
    if test -n "$flag"
        set mode $flag
        set origin --context
    else if test "$agentic" = 1
        set mode agentic
        set origin --agentic
    else
        set -l s (_ai_review_setting review_context $provider $model | string split \t)
        if test -n "$s[1]"
            set mode $s[1]
            set origin "config $s[2]"
        else
            set mode embedded
            set origin default
        end
    end
    if test "$mode" = assembled
        echo "Error: assembled is a verify context (the code the findings cite: a review has no findings yet); the review takes embedded or agentic (got it from $origin)" >&2
        return 1
    end
    if not contains -- $mode embedded agentic
        echo "Error: review context takes embedded or agentic (got '$mode' from $origin)" >&2
        return 1
    end
    printf '%s\t%s\n' $mode $origin
end
