function gbranch --description "Show branch overview: commits and diff stat vs base branch"
    argparse 'h/help' 'no-color' 'stat=' -- $argv; or return 1

    if set -q _flag_help
        echo "Usage: gbranch [OPTIONS] [BASE]"
        echo ""
        echo "Show commits and diff stat of current branch vs base branch."
        echo "Auto-detects the base with the fewest commits ahead among"
        echo "develop/main/master/release/stage, skipping one that already contains"
        echo "HEAD (override the list with \$GBRANCH_BASES), then prefers a nearer"
        echo "feature branch this one was cut from, or specify manually."
        echo ""
        echo "Options:"
        echo "      --stat=N     Set stat output width (default: terminal width)"
        echo "      --no-color   Disable colored output"
        echo "  -h, --help       Show this help"
        echo ""
        echo "Examples:"
        echo "  gbranch           Compare with auto-detected base"
        echo "  gbranch main      Compare with main"
        return 0
    end

    set -l color_flag --color=always
    if set -q _flag_no_color
        set color_flag --color=never
    end

    set -l repo_root (git rev-parse --show-toplevel 2>/dev/null)
    if test $status -ne 0
        echo "Not a git repository"
        return 1
    end

    set -l repo_name (basename $repo_root)
    set -l branch (git branch --show-current)

    # Determine base branch: explicit arg, or the nearest long-lived branch
    # (fewest commits base..HEAD) — a branch cut from release must not be
    # measured against develop, or every release merge shows up as "ahead"
    set -l base
    if test (count $argv) -eq 1
        set base $argv[1]
    else
        set -l candidates develop main master release stage
        if set -q GBRANCH_BASES
            # split too: exported from bash it arrives as one space-separated string
            set candidates (string split -n ' ' -- $GBRANCH_BASES)
        end
        if contains -- "$branch" $candidates
            set base $branch
        else
            set -l best_count
            set -l best_ref
            set -l contains_head
            set -l head_sha (git rev-parse HEAD)
            for c in $candidates
                set -l ref
                if git show-ref --verify --quiet refs/remotes/origin/$c
                    set ref origin/$c
                else if git show-ref --verify --quiet refs/heads/$c
                    set ref $c
                else
                    continue
                end
                # A base that already contains HEAD (the branch was merged into stage
                # for QA) would win with 0 and hide the branch's commits — keep it
                # only as a fallback for a branch with no commits of its own
                if git merge-base --is-ancestor HEAD $ref 2>/dev/null
                    # HEAD on the base's own first-parent line: the branch was just cut
                    # from it (no commits yet), so that base is exact. A branch merged
                    # into stage reaches it only through a merge's second parent
                    if git rev-list --first-parent $ref | string match -q -- $head_sha
                        set base $c
                        break
                    end
                    test -z "$contains_head"; and set contains_head $c
                    continue
                end
                set -l n (git rev-list --count $ref..HEAD 2>/dev/null); or continue
                if test -z "$best_count"; or test $n -lt $best_count
                    set best_count $n
                    set best_ref $ref
                    set base $c
                end
            end
            # A branch cut from another feature branch: the long-lived base counts
            # the parent's unmerged commits as ours. A nearer parent holds our first
            # commit past that base, so only those refs are worth measuring. The
            # graph can't tell a parent from a child cut from us (same commit, or
            # cut before our latest commits): a parent is the older one, by reflog
            set -l self_born (_gbranch_born $branch)
            if test -n "$best_count"; and test $best_count -gt 0; and test -n "$self_born"
                set -l mb (git merge-base $best_ref HEAD)
                set -l first (git rev-list --first-parent --reverse $mb..HEAD)[1]
                set -l near_count $best_count
                set -l near_behind
                for r in (git for-each-ref --contains $first --format='%(refname:short)' refs/heads refs/remotes)
                    set -l name (string replace -r '^origin/' '' -- $r)
                    if test "$name" = "$branch"; or test "$r" = origin; or string match -q -- '*/HEAD' $r
                        continue
                    end
                    contains -- $name $candidates; and continue
                    set -l born (_gbranch_born $name); or continue
                    test $born -lt $self_born; or continue
                    set -l lr (string split \t -- (git rev-list --left-right --count $r...HEAD))
                    set -l behind $lr[1]
                    set -l n $lr[2]
                    # Contains HEAD: a parent only if HEAD is on its own line, not a
                    # branch that merged ours in
                    if test $n -eq 0
                        git rev-list --first-parent $mb..$r | string match -q -- $head_sha; or continue
                    end
                    # Siblings cut from the same parent tie on ahead: the nearer
                    # relative has fewer commits of its own
                    if test $n -lt $near_count
                        or begin
                            test $n -eq $near_count; and test -n "$near_behind"; and test $behind -lt $near_behind
                        end
                        set near_count $n
                        set near_behind $behind
                        set base $name
                    end
                end
            end
            test -z "$base"; and set base $contains_head
        end
        if test -z "$base"
            echo "No base branch found, specify manually: gbranch <branch>"
            return 1
        end
    end

    if test "$branch" = "$base"
        echo "Repository: $repo_name ($branch)"
        set_color yellow
        echo "Already on $base — showing unpushed commits"
        set_color normal

        set -l unpushed (git rev-list --count origin/$base..HEAD 2>/dev/null; or echo 0)
        if test "$unpushed" -eq 0
            echo "---"
            echo "Up to date with origin/$base"
            return 0
        end

        echo ""
        set_color green
        echo "Commits:"
        set_color normal
        git log --oneline $color_flag origin/$base..HEAD | while read -l line
            echo "  $line"
        end

        set -l stat_flag --stat
        if set -q _flag_stat
            set stat_flag --stat=$_flag_stat
        else if test -n "$COLUMNS"
            set stat_flag --stat=$COLUMNS
        end

        echo ""
        set_color yellow
        echo "Files:"
        set_color normal
        set -l diff_stat (git diff $color_flag $stat_flag origin/$base..HEAD | string collect)
        if test -n "$diff_stat"
            echo "$diff_stat"
        end

        set -l nums (git diff --numstat origin/$base..HEAD | string match -rv '^\s*$')
        set -l total_add 0
        set -l total_del 0
        set -l total_files 0
        for line in $nums
            set -l parts (string split \t $line)
            if test "$parts[1]" != "-"
                set total_add (math $total_add + $parts[1])
                set total_del (math $total_del + $parts[2])
            end
            set total_files (math $total_files + 1)
        end

        echo "---"
        set -l summary "$unpushed unpushed commit(s), $total_files file(s)"
        if test $total_add -gt 0
            set summary "$summary, "(set_color green)"+$total_add"(set_color normal)
        end
        if test $total_del -gt 0
            set summary "$summary, "(set_color red)"-$total_del"(set_color normal)
        end
        echo $summary
        return 0
    end

    # Find merge base
    set -l merge_base (git merge-base origin/$base HEAD 2>/dev/null)
    if test -z "$merge_base"
        set merge_base (git merge-base $base HEAD 2>/dev/null)
        if test -z "$merge_base"
            echo "Cannot find common ancestor with $base"
            return 1
        end
    end

    set -l ahead (git rev-list --count $merge_base..HEAD)

    echo "Repository: $repo_name ($branch)"
    set_color cyan
    echo "Base: $base ($ahead commit(s) ahead)"
    set_color normal

    # Staged/unstaged work is part of the branch too, but not in any commit yet
    set -l uncommitted (git -c color.status=(string replace -- --color= '' $color_flag) status --short | string collect)

    if test "$ahead" -eq 0
        if test -n "$uncommitted"
            echo ""
            set_color magenta
            echo "Uncommitted:"
            set_color normal
            echo "$uncommitted" | string replace -r '^' '  '
        end
        echo "---"
        echo "No commits ahead of $base"
        return 0
    end

    # Commits
    echo ""
    set_color green
    echo "Commits:"
    set_color normal
    git log --oneline $color_flag $merge_base..HEAD | while read -l line
        echo "  $line"
    end

    # Diff stat
    set -l stat_flag --stat
    if set -q _flag_stat
        set stat_flag --stat=$_flag_stat
    else if test -n "$COLUMNS"
        set stat_flag --stat=$COLUMNS
    end

    echo ""
    set_color yellow
    echo "Files:"
    set_color normal
    set -l diff_stat (git diff $color_flag $stat_flag $merge_base..HEAD | string collect)
    if test -n "$diff_stat"
        echo "$diff_stat"
    end

    # Summary
    set -l nums (git diff --numstat $merge_base..HEAD | string match -rv '^\s*$')
    set -l total_add 0
    set -l total_del 0
    set -l total_files 0

    for line in $nums
        set -l parts (string split \t $line)
        if test "$parts[1]" != "-"
            set total_add (math $total_add + $parts[1])
            set total_del (math $total_del + $parts[2])
        end
        set total_files (math $total_files + 1)
    end

    if test -n "$uncommitted"
        echo ""
        set_color magenta
        echo "Uncommitted:"
        set_color normal
        echo "$uncommitted" | string replace -r '^' '  '
    end

    echo "---"
    set -l summary "$ahead commit(s), $total_files file(s)"
    if test $total_add -gt 0
        set summary "$summary, "(set_color green)"+$total_add"(set_color normal)
    end
    if test $total_del -gt 0
        set summary "$summary, "(set_color red)"-$total_del"(set_color normal)
    end
    echo $summary
end
