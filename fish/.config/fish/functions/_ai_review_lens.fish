function _ai_review_lens --description "Resolve --lens names to an injectable review block (or list available)"
    set -l lens_dir ~/.config/fish/prompts/lenses

    # No args: print available lens names (one per line, for completion/validation)
    if test (count $argv) -eq 0
        for f in $lens_dir/*.md
            set -l name (basename $f .md)
            test "$name" = README; and continue
            echo $name
        end
        return 0
    end

    # Split comma-separated names, validate, and assemble the block
    set -l names (string split , -- $argv | string trim | string match -rv '^$')
    set -l available (_ai_review_lens)

    set -l blocks
    for name in $names
        if not contains -- $name $available
            set_color red >&2
            echo "Error: unknown lens '$name'. Available: "(string join ', ' $available) >&2
            set_color normal >&2
            return 1
        end
        set -a blocks "## Security lens: $name
"(cat $lens_dir/$name.md | string collect)
    end

    printf '%s\n' "Apply the security lens(es) below IN ADDITION to the review above. The finding gate and severity rules still apply — a lens is where to look, not a mandate to find something. Report lens findings under the Critical/Important tiers by their real impact.
"
    printf '%s\n\n' $blocks
end
