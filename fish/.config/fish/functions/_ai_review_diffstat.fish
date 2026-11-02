function _ai_review_diffstat --description "git diff --stat of RANGE [FILE], indented as a block of the review header" --argument-names range file
    # The full stat, as git prints it — which files and how much — one space further in, so
    # it lines up under its heading. Piped, git would size it to 80 columns: the terminal's
    # width is passed on. --no-pager: never wait on bat/less.
    set -l width $COLUMNS
    test -n "$width"; or set width 120
    set -l args --no-pager diff $range --stat=(math $width - 1)
    test -n "$file"; and set -a args -- $file
    git $args 2>/dev/null | string replace -r '^' ' '
end
