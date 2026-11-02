function _ai_stage_plan --description "Print the planned review stages (to stderr, before work begins)"
    # Args: one string per stage, in order.
    _ai_ui_heading Stages >&2
    for i in (seq (count $argv))
        printf '  %d. %s\n' $i $argv[$i] >&2
    end
end
