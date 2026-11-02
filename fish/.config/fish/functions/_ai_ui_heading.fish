function _ai_ui_heading --description "A block heading of the review output: an empty line, the title in bold, an optional note dimmed" --argument-names title note
    # One look for every block (a stage, the saved files): the title at the left edge, the
    # block's lines indented by 2 under it (_ai_ui_kv, the run rows of _ai_run_watched).
    # On stdout; a stage heading goes to stderr with the stage's other lines (>&2).
    echo
    set_color --bold
    printf '%s' $title
    set_color normal
    if test -n "$note"
        set_color brblack
        printf '  %s' $note
        set_color normal
    end
    echo
end
