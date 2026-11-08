function _ai_verify_context --description "The code a verify pass needs, assembled without a model: the lines each finding cites and where the names it quotes are used"
    # Usage: _ai_verify_context [--window N] [--budget N] [--diff FILE] FINDINGS ROOT
    # An agentic verify spent 4-8 turns of ~60 s each finding the code a finding already
    # names by file:line; read here instead, the verifier answers in one request. From the
    # working tree, as an agentic verifier would read it:
    # - N lines (--window, 40) around each "path:12" / "path:12-15" a numbered finding cites;
    #   a bare ":12" is in the file the finding named last, a path not found as written is
    #   looked up by its tail ("gbranch.fish:24"), and among several the changed one wins
    #   (--diff: the files after "+++ b/")
    # - the names a finding quotes in backticks, followed with git grep -w: up to 5 places,
    #   3 lines each, in the files the finding cites first, then the changed ones. A name
    #   used more than 30 times is too common to tell anything.
    # The cited lines go first; the places that use a name fill what --budget (1500 lines)
    # leaves. Prints the files with their line numbers, then what could not be found.
    argparse 'window=' 'budget=' 'diff=' -- $argv; or return 1
    set -l findings $argv[1]
    set -l root $argv[2]
    set -l window 40
    test -n "$_flag_window"; and set window $_flag_window
    set -l budget 1500
    test -n "$_flag_budget"; and set budget $_flag_budget
    set -l around 3
    set -l per_name 5
    set -l too_common 30

    # F<n> (a finding), R<tab>F<n><tab>path<tab>a<tab>b (a cited line), N<tab>F<n><tab>name
    set -l items (awk '
        BEGIN { OFS = "\t" }
        /^ *```/ { fence = !fence; next }
        fence { next }
        /^#{1,2} / { cur = ""; next }
        {
            if (match($0, /^( {0,3}([-*]|[0-9]+\.)|#+) \[F[0-9]+\] /)) {
                s = substr($0, RSTART, RLENGTH); sub(/^.*\[F/, "", s); sub(/\].*$/, "", s)
                cur = "F" s; last = ""; named[cur] = 0; print "F", cur
            }
            if (cur == "") next
            rest = $0
            while (match(rest, /([A-Za-z0-9_.\/-]+\.[A-Za-z0-9]+)?:[0-9]+(-[0-9]+)?/)) {
                tok = substr(rest, RSTART, RLENGTH)
                pre = RSTART > 1 ? substr(rest, RSTART - 1, 1) : " "
                rest = substr(rest, RSTART + RLENGTH)
                p = tok; sub(/:[0-9]+(-[0-9]+)?$/, "", p)
                r = tok; sub(/^.*:/, "", r)
                # A bare ":12" only after a space, a backtick or a bracket: "10:30" is a time
                if (p == "") { if (last == "" || pre ~ /[A-Za-z0-9_]/) continue; p = last }
                else last = p
                a = r; sub(/-.*$/, "", a)
                b = r; if (b ~ /-/) sub(/^.*-/, "", b); else b = a
                print "R", cur, p, a, b
            }
            # Names in backticks; a path or a file name there is not a name to follow
            n = split($0, part, "`")
            for (i = 2; i <= n; i += 2) {
                code = part[i]
                gsub(/[A-Za-z0-9_.-]*\/[A-Za-z0-9_.\/-]*/, " ", code)
                gsub(/[A-Za-z0-9_.-]+:[0-9]+(-[0-9]+)?/, " ", code)
                gsub(/[A-Za-z0-9_-]+\.(java|scala|sc|kt|kts|rs|fish|sh|py|ts|js|go|md|json|ya?ml|toml|xml|sql|conf|gradle|sbt)/, " ", code)
                while (match(code, /[A-Za-z_][A-Za-z0-9_]*/)) {
                    w = substr(code, RSTART, RLENGTH)
                    code = substr(code, RSTART + RLENGTH)
                    if (length(w) < 4 || named[cur] >= 6 || (cur SUBSEP w) in seen) continue
                    if (w ~ /^(null|true|false|this|self|super|return|final|static|public|private|protected|void|class|else|case|default|break|continue|throw|throws|catch|finally|while|import|package|const|async|await|func|function|String|string|Integer|Long|Boolean|Object|List|Map|Set|Optional|Some|None|Unit|then|when|match|echo|test|status|argv|count)$/) continue
                    seen[cur SUBSEP w] = 1; named[cur]++
                    print "N", cur, w
                }
            }
        }' $findings)

    set -l changed
    test -n "$_flag_diff"; and test -f "$_flag_diff"
    and set changed (string match -r -g '^\+\+\+ b/(.*)$' <$_flag_diff)
    set -l in_git 0
    git -C $root rev-parse --git-dir >/dev/null 2>&1; and set in_git 1
    set -l all_files

    # path<tab>a<tab>b<tab>F<n>: the cited windows first, then the places that use a name
    set -l cited
    set -l used
    set -l missing
    set -l lineless
    for it in $items
        set -l f (string split \t -- $it)
        switch $f[1]
            case F
                string match -q -r -- "^R\t$f[2]\t" $items; or set -a lineless $f[2]
            case R
                set -l p (string replace -r '^(\./|[ab]/)' '' -- $f[3])
                if not test -f "$root/$p"
                    if test (count $all_files) -eq 0
                        if test $in_git -eq 1
                            set all_files (git -C $root ls-files)
                        else
                            set all_files (find $root -type f -not -path '*/.git/*' | string replace -- "$root/" '')
                        end
                    end
                    set -l hits (string match -- "*/$p" $all_files)
                    if test (count $hits) -gt 1
                        set -l mine
                        for h in $hits
                            contains -- $h $changed; and set -a mine $h
                        end
                        set hits $mine
                    end
                    if test (count $hits) -ne 1
                        set -a missing "$f[2] $f[3]:$f[4]"
                        continue
                    end
                    set p $hits[1]
                end
                set -l len (count (cat $root/$p))
                if test $f[4] -gt $len
                    set -a missing "$f[2] $f[3]:$f[4] (the file has $len lines)"
                    continue
                end
                set -l a (math "max(1, $f[4] - $window)")
                set -l b (math "min($len, $f[5] + $window)")
                set -a cited "$p"\t$a\t$b\t$f[2]
        end
    end
    # Where a quoted name is used, outside the windows already taken
    for it in (string match -r -e -- '^N\t' $items)
        set -l f (string split \t -- $it)
        set -l hits
        if test $in_git -eq 1
            set hits (git -C $root grep -n -w -F -e $f[3] 2>/dev/null)
        else
            set hits (grep -r -n -w -F -e $f[3] $root 2>/dev/null | string replace -- "$root/" '')
        end
        test (count $hits) -gt $too_common; and continue
        # Nearest first: the files this finding cites, then the changed ones, then the rest
        set -l own
        for w in $cited
            set -l c (string split \t -- $w)
            test "$c[4]" = "$f[2]"; and set -a own $c[1]
        end
        set -l first
        set -l second
        set -l rest
        for h in $hits
            set -l p (string replace -r ':[0-9]+:.*$' '' -- $h)
            if contains -- $p $own
                set -a first $h
            else if contains -- $p $changed
                set -a second $h
            else
                set -a rest $h
            end
        end
        set -l taken 0
        for h in $first $second $rest
            test $taken -ge $per_name; and break
            set -l m (string match -r -g '^(.*?):([0-9]+):' -- $h)
            test (count $m) -eq 2; or continue
            set -l inside 0
            for w in $cited
                set -l c (string split \t -- $w)
                if test "$c[1]" = "$m[1]"; and test $m[2] -ge $c[2]; and test $m[2] -le $c[3]
                    set inside 1
                    break
                end
            end
            test $inside -eq 1; and continue
            set -a used "$m[1]"\t(math "max(1, $m[2] - $around)")\t(math "$m[2] + $around")\t$f[2]
            set taken (math $taken + 1)
        end
    end

    # The budget: cited windows in finding order, then the places that use a name
    set -l kept
    set -l total 0
    set -l cut_cited
    set -l cut_used 0
    set -l n_cited (count $cited)
    set -l i 0
    for w in $cited $used
        set i (math $i + 1)
        set -l c (string split \t -- $w)
        set -l n (math $c[3] - $c[2] + 1)
        if test (math $total + $n) -gt $budget
            if test $i -le $n_cited
                contains -- $c[4] $cut_cited; or set -a cut_cited $c[4]
            else
                set cut_used (math $cut_used + 1)
            end
            continue
        end
        set total (math $total + $n)
        set -a kept $w
    end

    # Windows merged per file (overlapping or touching); the files in the order the findings
    # cite them, the files only a name led to after them
    set -l merged (printf '%s\n' $kept | sort -t \t -k1,1 -k2,2n | awk -F '\t' '
        function flush() { if (p != "") print p "\t" a "\t" b "\t" fs }
        $1 != p || $2 > b + 1 { flush(); p = $1; a = $2; b = $3; fs = $4; next }
        { if ($3 > b) b = $3; if (index("," fs ",", "," $4 ",") == 0) fs = fs "," $4 }
        END { flush() }')
    set -l order
    for w in $kept
        set -l p (string split \t -- $w)[1]
        contains -- $p $order; or set -a order $p
    end
    for p in $order
        set -l ranges (string match -e -r -- "^"(string escape --style=regex -- $p)"\t" $merged)
        # Every finding this file serves, over all its windows
        set -l fs (for r in $ranges; string split , -- (string split \t -- $r)[4]; end | sort -u | sort -k1.2n | string join ', ')
        printf '### %s (%s)\n```\n' $p "$fs"
        set -l first 1
        for r in $ranges
            set -l c (string split \t -- $r)
            test $first -eq 1; or printf '  ...\n'
            set first 0
            awk -v a=$c[2] -v b=$c[3] 'NR >= a && NR <= b { printf "%5d  %s\n", NR, $0 } NR > b { exit }' $root/$p
        end
        printf '```\n\n'
    end

    set -l notes
    test (count $missing) -gt 0; and set -a notes "Not found in the repository: "(string join ', ' -- $missing)"."
    test (count $lineless) -gt 0; and set -a notes "Cite no line: "(string join ', ' -- $lineless)"."
    test (count $cut_cited) -gt 0; and set -a notes "Left out to keep to $budget lines, though cited: "(string join ', ' -- $cut_cited)"."
    test $cut_used -gt 0; and set -a notes "Left out to keep to $budget lines: $cut_used place(s) that use a quoted name."
    printf '%s\n' $notes
    return 0
end
