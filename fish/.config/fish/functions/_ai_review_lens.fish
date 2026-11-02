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

    # --verify: the same lenses for the verify pass — knowledge to judge findings by
    # (semantics, versions, "Not bugs"), not places to hunt for new ones
    set -l for_verify 0
    if test "$argv[1]" = --verify
        set for_verify 1
        set -e argv[1]
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
        set -a blocks "## Review lens: $name
"(cat $lens_dir/$name.md | string collect)
    end

    if test $for_verify -eq 1
        printf '%s\n' "The review was run with the lens(es) below. Use them as domain knowledge while you try to kill each finding. A finding that rests on a misread of semantics or versions the lens corrects (what an operator does, which API a version has) is REFUTED. A \"Not bugs\" item kills a finding only when its condition is shown to hold in THIS code, for this exact kind of state: \"a single writer\" means you counted every writer — listener, scheduler, startup and request threads, and other instances of the service — and found one; an item about a Redis key says nothing about a field in memory. If the condition is not shown, judge the finding by steps A-D as usual. Do not raise new findings from the lenses.
"
        printf '%s\n\n' $blocks
        return 0
    end
    printf '%s\n' "Apply the lens(es) below IN ADDITION to the review above. The finding gate and severity rules still apply — a lens is where to look, not a mandate to find something. Report lens findings under the Critical/Important tiers by their real impact.
"
    printf '%s\n\n' $blocks
end
