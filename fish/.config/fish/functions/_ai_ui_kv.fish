function _ai_ui_kv --description "One key/value line of a review output block: the key in a fixed column, the value as is, an optional note dimmed" --argument-names key value note
    # An empty key continues the value of the line above (a second file of one stage).
    # Values are printed whole — a path stays usable as it is (copy, ctrl-click).
    printf '  %-13s%s' $key $value
    if test -n "$note"
        set_color brblack
        printf '  %s' $note
        set_color normal
    end
    echo
end
