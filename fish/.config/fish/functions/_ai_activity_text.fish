function _ai_activity_text --description "What the model does, in words, from an ACTIVITY of _ai_session_progress: reading context, thinking 3.1k chars, writing 2k chars"
    # ACTIVITY: "reading", "thinking N", "writing N", or "retry N MESSAGE" (pi sends a failed
    # request again). One wording for the run's live line and for the stage line of parallel
    # runs.
    set -l act (string split ' ' -- "$argv[1]")
    switch "$act[1]"
        case reading
            echo "reading context"
        case retry
            # pi gave up on the request and sends it again: the model reads the prompt anew
            echo "reading context, retry $act[2] ($act[3..])"
        case thinking writing
            echo "$act[1] "(_ai_k $act[2])" chars"
        case '*'
            echo model
    end
end
