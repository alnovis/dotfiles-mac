function _ai_review_comments_anchor --description "Anchor extracted comments (JSON array file) to real lines: prints the comments JSON for GitLab/GitHub" --argument-names comments_file range root runs
    test -n "$runs"; or set runs 1
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
            set -l name (path basename -- $path)
            set -l name_re (string escape --style=regex -- $name)
            set -l by_name (printf '%s\n' $files_at_head | string match -r --entire -- '(?:^|/)'$name_re'$')
            # A bare class name ("SendTicketContainerizedTest") names the file without its
            # extension
            if test (count $by_name) -eq 0; and test -n "$name"; and not string match -q -- '*.*' $name
                set by_name (printf '%s\n' $files_at_head | string match -r --entire -- '(?:^|/)'$name_re'\.[^./]+$')
            end
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
                # A cited number is often a few lines off, landing on "try {" or a blank. When
                # the cited line names none of the code the comment talks about and a line
                # nearby does, the nearby one is meant.
                set -l tokens (_ai_review_comments_tokens (printf '%s' $c | jq -r '(.quote // "") + "\n" + (.body // "")'))
                set -l near (_ai_review_comments_nearby $want $tokens -- $new_lines)
                if test -n "$near"; and test $near -ne $want
                    set line $near
                    set by nearby
                    set code $new_lines[$line]
                end
            end
            # No line and no quote: the comments model sees no code, so a review that names a
            # method without showing it ("`loadFromRedis()` swaps…") leaves it nothing to
            # quote. The changed line of this file that names that code is meant.
            if test $line -eq 0; and test -n "$base"
                set -l tokens (_ai_review_comments_tokens (printf '%s' $c | jq -r '(.quote // "") + "\n" + (.body // "")'))
                set -l named (_ai_review_comments_by_name $root $path $tokens -- $base $head)
                if test -n "$named"
                    set line $named
                    set side new
                    set by name
                    set code $new_lines[$line]
                end
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

        # A file the repo has but no line to put the comment on (a missing test, a stale
        # document): a file-level comment, posted as a general one — not "unanchored"
        set -l found false
        contains -- $path $files_at_head; and set found true
        printf '%s' $c | jq -c --arg path $path --arg side "$side" --argjson line $line --argjson in_diff $in_diff \
            --arg by "$by" --arg code "$code" --argjson found $found --argjson runs $runs \
            '{path: $path, side: (if $side == "" then null else $side end), line: (if $line > 0 then $line else null end),
              line_cited: (if (.line // 0) > 0 then .line else null end), anchored: ($side != ""),
              anchored_by: (if $by == "" then null else $by end),
              file_level: ($side == "" and $found and ((.line // 0) <= 0)),
              code: (if $side == "" then null else $code end), quote: (.quote // ""), in_diff: $in_diff,
              seen: ([((.seen // 1) | tonumber? // 1), 1] | max | [., $runs] | min), runs: $runs,
              severity: (.severity // "important"), status: (.status // "confirmed"), body: (.body // "")}' >>$out
    end

    # In line order within a file — neighbouring comments are often about one thing:
    # whole-file first, then new lines, then old (removed) lines — each side numbers its
    # own file — then the unanchored ones. "order" carries that for the markdown too.
    jq -s --arg base "$base" --arg head "$head" --argjson runs $runs \
        'map(. + {order: [(if .file_level then 0 elif .side == "new" then 1 elif .side == "old" then 2 else 3 end),
                          (.line // .line_cited // 0)]})
         | sort_by(.path, .order)
         | {base_sha: (if $base == "" then null else $base end), head_sha: (if $head == "" then null else $head end),
            start_sha: (if $base == "" then null else $base end), runs: $runs, comments: .}' $out
    rm -f $out
end

function _ai_review_comments_tokens --description "Code names a comment talks about: `quoted` spans first, then camelCase / CONSTANT words (4+ characters)"
    set -l text (string collect -- $argv)
    set -l tokens
    # `loadFromRedis()` → loadFromRedis; `RENAME` → RENAME
    for span in (string match -r -a -g '`([^`]+)`' -- $text)
        set -a tokens (string match -r -g '^([A-Za-z_][A-Za-z0-9_.]*)' -- $span)
    end
    set -a tokens (string match -r -a -- '\b[a-z]+[A-Z][A-Za-z0-9_]*\b|\b[A-Z][A-Z0-9_]{3,}\b' -- $text)
    for t in $tokens
        test (string length -- $t) -ge 4; and echo $t
    end | awk '!seen[$0]++'
end

function _ai_review_comments_nearby --description "Line within 10 of WANT that contains one of TOKENS (nearest; 0 if the WANT line already does or none does): args WANT TOKENS… -- LINES…"
    set -l want $argv[1]
    set -l sep (contains -i -- -- $argv)
    # No tokens (sep right after WANT): fish's $argv[2..1] would count backwards, not be empty
    test -n "$sep"; and test $sep -gt 2; or return
    set -l tokens $argv[2..(math $sep - 1)]
    set -l lines $argv[(math $sep + 1)..]
    test (count $tokens) -gt 0; or return
    # Case-insensitive: prose says RENAME, the Java says .rename(
    set -l has '(?i)'(string escape --style=regex -- $tokens | string join '|')
    # The cited line already names it: keep it
    string match -q -r -- $has $lines[$want]; and return
    set -l best 0
    set -l from (math "max(1, $want - 10)")
    set -l to (math "min("(count $lines)", $want + 10)")
    for i in (seq $from $to)
        if string match -q -r -- $has $lines[$i]
            if test $best -eq 0; or test (math "abs($i - $want)") -lt (math "abs($best - $want)")
                set best $i
            end
        end
    end
    test $best -gt 0; and echo $best
end

function _ai_review_comments_by_name --description "New-side line of PATH's diff that names one of TOKENS (in token order; an added line before a context line; empty if none): args ROOT PATH TOKENS… -- BASE [HEAD]"
    set -l root $argv[1]
    set -l path $argv[2]
    set -l sep (contains -i -- -- $argv)
    test -n "$sep"; and test $sep -gt 3; or return
    set -l tokens $argv[3..(math $sep - 1)]
    set -l revs $argv[(math $sep + 1)..]
    # "N<tab>+|space<tab>text" for each new-side line inside a hunk; removed lines are skipped
    set -l rows (git -C $root diff -U3 $revs -- $path 2>/dev/null | awk '
        /^@@/ { match($0, /\+[0-9]+/); n = substr($0, RSTART + 1, RLENGTH - 1); h = 1; next }
        !h { next }
        /^\+/ { print n "\t+\t" substr($0, 2); n++; next }
        /^ /  { print n "\t \t" substr($0, 2); n++; next }')
    test (count $rows) -gt 0; or return
    for t in $tokens
        # Case-insensitive, as in _ai_review_comments_nearby
        set -l re '(?i)'(string escape --style=regex -- $t)
        for kind in + ' '
            for r in $rows
                set -l f (string split -m2 \t -- $r)
                if test "$f[2]" = "$kind"; and string match -q -r -- $re $f[3]
                    echo $f[1]
                    return
                end
            end
        end
    end
end

function _ai_review_comments_content --description "Lines of PATH at REV (empty REV: the file in ROOT)" --argument-names root rev path
    if test -n "$rev"
        git -C $root show "$rev:$path" 2>/dev/null
    else
        cat $root/$path 2>/dev/null
    end
end

function _ai_review_comments_find --description "Line of QUOTE in the lines given after WANT: exact trimmed match first, then containment, then containment ignoring whitespace over 1-3 lines; the nearest to WANT wins; 0 if absent"
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
    # A statement the code splits over lines and the model quotes as one line (or spaces
    # differently): compare without whitespace over 1, then 2, then 3 consecutive lines.
    # The first line of the window is the anchor. Short quotes would match by chance.
    if test (count $pool) -eq 0
        set -l q (string replace -ar '\s+' '' -- $quote)
        if test (string length -- "$q") -ge 8
            set -l q_re (string escape --style=regex -- $q)
            set -l flat (string replace -ar '\s+' '' -- $lines)
            for k in 1 2 3
                test (count $flat) -ge $k; or break
                for i in (seq 1 (math (count $flat) - $k + 1))
                    string match -q -r -- $q_re (string join '' -- $flat[$i..(math $i + $k - 1)]); and set -a pool $i
                end
                test (count $pool) -gt 0; and break
            end
        end
    end
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
