function _ai_review_template --description "Review template FILE for MODE (full|lean): lean drops the <!-- full-only --> blocks" --argument-names file mode
    # The markers are whole lines, so a template without them (a user override) passes
    # through unchanged in either mode
    if test "$mode" = full
        string match -v -r '^<!-- /?full-only -->$' <$file | string collect
    else
        awk '/^<!-- full-only -->$/ { skip = 1; next } /^<!-- \/full-only -->$/ { skip = 0; next } !skip' $file | string collect
    end
end
