function _ai_review_commit_range --description "Resolve --commit SPEC (SHA, A..B or SHA1,SHA2,…) into a reviewable range: prints RANGE, TIP, then the commits oldest first; fails on a broken range" --argument-names spec
    # A review covers one whole change. A range with a merge inside, or a list of commits
    # with someone else's commit between them, would mix other changes into the diff —
    # so it is refused with the reason, and a broken list gets the contiguous pieces as
    # ready commands instead.
    set -l empty_tree (git hash-object -t tree /dev/null)

    # --- A..B -----------------------------------------------------------------------
    if string match -q -- '*..*' $spec
        set -l ends (string split -m1 -- '..' $spec)
        for e in $ends
            if not git rev-parse --verify -q "$e^{commit}" >/dev/null
                echo "Error: commit '$e' not found" >&2
                return 1
            end
        end
        if not git merge-base --is-ancestor $ends[1] $ends[2]
            echo "Error: $ends[1] is not an ancestor of $ends[2] — not a range" >&2
            return 1
        end
        set -l commits (git log --reverse --format='%h %s' $ends[1]..$ends[2])
        if test (count $commits) -eq 0
            echo "Error: $spec is empty — no commits after $ends[1] up to $ends[2]" >&2
            return 1
        end
        _ai_review_commit_range_linear $ends[1]..$ends[2]; or return 1
        echo $ends[1]..$ends[2]
        echo $ends[2]
        printf '%s\n' $commits
        return 0
    end

    # --- one SHA or a list ----------------------------------------------------------
    set -l shas
    for s in (string split , -- $spec | string trim | string match -v '')
        set -l full (git rev-parse --verify -q "$s^{commit}")
        if test -z "$full"
            echo "Error: commit '$s' not found" >&2
            return 1
        end
        contains -- $full $shas; or set -a shas $full
    end

    if test (count $shas) -eq 1
        # As the user wrote it, so the range in the header reads like the command line.
        # A root commit has no parent — diff it against the empty tree.
        set -l c (string trim -- $spec | string trim -c ,)
        set -l parent $c~1
        git rev-parse --verify -q "$parent" >/dev/null; or set parent $empty_tree
        echo $parent..$c
        echo $c
        git log -1 --format='%h %s' $c
        return 0
    end

    # The newest is the one every other commit leads up to; none such → two lines of history
    set -l tip
    for c in $shas
        set -l all 1
        for o in $shas
            test $o = $c; and continue
            git merge-base --is-ancestor $o $c; or begin
                set all 0
                break
            end
        end
        if test $all -eq 1
            set tip $c
            break
        end
    end
    if test -z "$tip"
        echo "Error: these commits are not on one line of history — no single change to review" >&2
        return 1
    end
    set -l oldest
    for c in $shas
        set -l first 1
        for o in $shas
            test $o = $c; and continue
            git merge-base --is-ancestor $c $o; or begin
                set first 0
                break
            end
        end
        if test $first -eq 1
            set oldest $c
            break
        end
    end

    # The list in history order; a piece goes on while the next commit is the direct,
    # single-parent child of the last one. Anything else between two listed commits — a
    # merge, another task's commit — is a break.
    set -l short_oldest (git rev-parse --short $oldest)
    set -l base $short_oldest~1
    git rev-parse --verify -q "$base" >/dev/null; or set base $empty_tree
    set -l ordered
    if test $base = $empty_tree
        set ordered (git rev-list --reverse --topo-order $tip)
    else
        set ordered (git rev-list --reverse --topo-order $base..$tip)
    end
    set -l pieces    # "first last" per piece
    set -l first
    set -l last
    for c in $ordered
        contains -- $c $shas; or continue
        if test -n "$last"; and test "$(git rev-parse -q --verify $c^1)" = $last
            and not git rev-parse -q --verify $c^2 >/dev/null
            set last $c
        else
            test -n "$first"; and set -a pieces "$first $last"
            set first $c
            set last $c
        end
    end
    set -a pieces "$first $last"

    if test (count $pieces) -gt 1
        echo "Error: the range is broken — other commits sit between the listed ones:" >&2
        set -l prev
        for p in $pieces
            set -l ends (string split ' ' -- $p)
            if test -n "$prev"
                echo "  between "(git rev-parse --short $prev)" and "(git rev-parse --short $ends[1])":" >&2
                git log --reverse --format='    %h %s' $prev..$ends[1]~1 2>/dev/null | head -6 >&2
            end
            set prev $ends[2]
        end
        echo "Review the pieces separately:" >&2
        for p in $pieces
            set -l ends (string split ' ' -- $p)
            if test $ends[1] = $ends[2]
                echo "  ai review --commit "(git rev-parse --short $ends[1]) >&2
            else
                echo "  ai review --commit "(git rev-parse --short $ends[1])"~1.."(git rev-parse --short $ends[2]) >&2
            end
        end
        return 1
    end

    echo $base..(git rev-parse --short $tip)
    echo $tip
    for c in $ordered
        contains -- $c $shas; and git log -1 --format='%h %s' $c
    end
end

function _ai_review_commit_range_linear --description "Fails (with the merges listed) when RANGE contains a merge commit" --argument-names range
    set -l merges (git rev-list --merges $range)
    test (count $merges) -eq 0; and return 0
    echo "Error: $range is not linear — the diff would mix in other changes:" >&2
    for m in $merges
        echo "  merge "(git log -1 --format='%h %s' $m) >&2
    end
    echo "Review the commits on either side of the merge separately, or the feature branch itself." >&2
    return 1
end
