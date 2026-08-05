function _ai_complete_lens --description "Complete comma-separated --lens values (stacked lenses)"
    # --lens takes a comma-separated stack: `ai review --lens crypto,logic-bug`.
    # Bare `-a "(_ai_review_lens)"` only completes the FIRST lens: it replaces the
    # whole token, so after `crypto,` the second name never attaches. Here we read
    # the current token, keep the already-typed `prefix,` intact, and offer
    # `prefix,<remaining>` — skipping lenses already chosen in the same stack.
    set -l all (_ai_review_lens)
    set -l token (commandline -ct)

    if string match -q '*,*' -- $token
        # Everything up to and including the last comma stays; last segment is partial.
        set -l prefix (string replace -r '[^,]*$' '' -- $token)
        set -l chosen (string split , -- $prefix | string trim | string match -rv '^$')
        for name in $all
            contains -- $name $chosen; and continue
            echo "$prefix$name"
        end
    else
        printf '%s\n' $all
    end
end
