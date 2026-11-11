function _ai_verify_context_mode --description "What the verify pass sees, for the verify PROVIDER/MODEL: --verify-context FLAG > verify_context (scoped) > the review's mode; prints mode<TAB>origin" --argument-names provider model flag agentic
    # embedded   the code the review saw, in the prompt; no tools
    # assembled  that, plus the code each finding cites, read beforehand (_ai_verify_context);
    #            no tools
    # agentic    read-only tools and the ai-verify skill; the model reads what it needs
    # With neither the flag nor the key, verify follows the review: an --agentic review gets
    # an agentic verify, any other gets embedded. AGENTIC is "1" when the review is agentic.
    # The flag and the key decide verify alone, so --agentic --verify-context assembled is an
    # agentic review with an assembled verify.
    set -l mode
    set -l origin
    if test -n "$flag"
        set mode $flag
        set origin --verify-context
    else
        set -l s (_ai_review_setting verify_context $provider $model | string split \t)
        if test -n "$s[1]"
            set mode $s[1]
            set origin "config $s[2]"
        else if test "$agentic" = 1
            # --agentic, --context agentic or review_context: the review's mode, whichever
            set mode agentic
            set origin "the review's mode"
        else
            set mode embedded
            set origin default
        end
    end
    if not contains -- $mode embedded assembled agentic
        echo "Error: verify context takes embedded, assembled or agentic (got '$mode' from $origin)" >&2
        return 1
    end
    printf '%s\t%s\n' $mode $origin
end
