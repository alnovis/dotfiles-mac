function _ai_stage_plan --description "Print the planned review stages (to stderr, before work begins)"
    # Args: one string per stage, in order.
    printf 'Stages:\n' >&2
    for i in (seq (count $argv))
        printf '  %d. %s\n' $i $argv[$i] >&2
    end
    printf '\n' >&2
end
