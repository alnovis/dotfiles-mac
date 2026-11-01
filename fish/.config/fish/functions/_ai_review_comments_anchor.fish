function _ai_review_comments_anchor --description "Anchor extracted comments (JSON array file) to real lines: prints the comments JSON for GitLab/GitHub" --argument-names comments_file range root
    # No model here. A model's line numbers are often off, so the line is found again by
    # the quote: first in the new version of the file, then in the old one (removed code).
    # The model's number only breaks ties. in_diff says whether the line sits inside a
    # diff hunk — GitLab and GitHub accept a line comment only there. RANGE "BASE..HEAD"
    # (empty: the working tree, no diff check); ROOT is the repo or directory.
    set -l base
    set -l head
    if test -n "$range"
        set -l ends (string split -m1 -- '..' $range)
        set base (git -C $root rev-parse -q --verify "$ends[1]^{commit}" 2>/dev/null)
        set head (git -C $root rev-parse -q --verify "$ends[2]^{commit}" 2>/dev/null)
    end
    set -l files_at_head
    if test -n "$head"
        set files_at_head (git -C $root ls-tree -r --name-only $head)
    else
        set files_at_head (git -C $root ls-files 2>/dev/null)
        # Not a repo (a directory review outside git): the files on disk
        test (count $files_at_head) -gt 0; or set files_at_head (find $root -type f -not -path '*/.*' | string replace -- "$root/" '')
    end

    set -l out (mktemp)
    for c in (jq -c '.[]' $comments_file)
        set -l path (printf '%s' $c | jq -r '.file // ""' | string replace -r '^(\./|a/|b/)' '')
        set -l want (printf '%s' $c | jq -r '.line // 0')
        set -l quote (printf '%s' $c | jq -r '.quote // ""' | string trim)

        # The path as cited; else the one file with that name ("src/.../X.java" is common)
        if not contains -- $path $files_at_head
            set -l by_name (printf '%s\n' $files_at_head | string match -r --entire -- '(?:^|/)'(string escape --style=regex -- (path basename -- $path))'$')
            test (count $by_name) -eq 1; and set path $by_name[1]
        end

        set -l side ""
        set -l line 0
        set -l by ""
        set -l code ""
        if contains -- $path $files_at_head
            set -l new_lines (_ai_review_comments_content $root "$head" $path)
            if test -n "$quote"
                set line (_ai_review_comments_find "$quote" $want $new_lines)
                if test $line -gt 0
                    set side new
                    set code $new_lines[$line]
                else if test -n "$base"
                    set -l old_lines (_ai_review_comments_content $root "$base" $path)
                    set line (_ai_review_comments_find "$quote" $want $old_lines)
                    test $line -gt 0; and set side old; and set code $old_lines[$line]
                end
                test $line -gt 0; and set by quote
            end
            # The quote did not match (models invent one when the review never showed the
            # line): fall back to the cited number when the file has it — flagged, with the
            # real line shown so a human sees where the comment would land
            if test $line -eq 0; and test $want -gt 0; and test $want -le (count $new_lines)
                set line $want
                set side new
                set by line
                set code $new_lines[$line]
            end
        end

        set -l in_diff false
        if test -n "$side"; and test -n "$base"
            for h in (git -C $root diff -U3 $base $head -- $path | string match -r -g '^@@ -(\d+(?:,\d+)?) \+(\d+(?:,\d+)?) @@')
                # h alternates old range, new range; take the one for this side
                set -a hunks $h
            end
            set -l i 1
            while test $i -lt (count $hunks)
                set -l r $hunks[$i]
                test $side = new; and set r $hunks[(math $i + 1)]
                set -l p (string split , -- $r)
                set -l n 1
                test (count $p) -eq 2; and set n $p[2]
                if test $n -gt 0; and test $line -ge $p[1]; and test $line -lt (math $p[1] + $n)
                    set in_diff true
                    break
                end
                set i (math $i + 2)
            end
            set -e hunks
        end

        printf '%s' $c | jq -c --arg path $path --arg side "$side" --argjson line $line --argjson in_diff $in_diff \
            --arg by "$by" --arg code "$code" \
            '{path: $path, side: (if $side == "" then null else $side end), line: (if $line > 0 then $line else null end),
              line_cited: (.line // null), anchored: ($side != ""), anchored_by: (if $by == "" then null else $by end),
              code: (if $side == "" then null else $code end), quote: (.quote // ""), in_diff: $in_diff,
              severity: (.severity // "important"), status: (.status // "confirmed"), body: (.body // "")}' >>$out
    end

    jq -s --arg base "$base" --arg head "$head" \
        '{base_sha: (if $base == "" then null else $base end), head_sha: (if $head == "" then null else $head end),
          start_sha: (if $base == "" then null else $base end), comments: .}' $out
    rm -f $out
end

function _ai_review_comments_content --description "Lines of PATH at REV (empty REV: the file in ROOT)" --argument-names root rev path
    if test -n "$rev"
        git -C $root show "$rev:$path" 2>/dev/null
    else
        cat $root/$path 2>/dev/null
    end
end

function _ai_review_comments_find --description "Line of QUOTE in the lines given after WANT: exact trimmed match first, then containment; the nearest to WANT wins; 0 if absent"
    set -l quote $argv[1]
    set -l want $argv[2]
    set -l lines $argv[3..]
    set -l exact
    set -l partial
    set -l n 0
    # Literal containment: the quote is code, full of glob and regex characters
    set -l literal (string escape --style=regex -- $quote)
    for l in $lines
        set n (math $n + 1)
        set -l t (string trim -- $l)
        if test "$t" = "$quote"
            set -a exact $n
        else if string match -q -r -- $literal $l
            set -a partial $n
        end
    end
    set -l pool $exact
    test (count $pool) -eq 0; and set pool $partial
    if test (count $pool) -eq 0
        echo 0
        return
    end
    set -l best $pool[1]
    for p in $pool
        test (math "abs($p - $want)") -lt (math "abs($best - $want)"); and set best $p
    end
    echo $best
end
