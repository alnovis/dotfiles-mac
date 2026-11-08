function _ai_lessons_register --description "Remember a comments file in the reviews registry, so ai lessons finds it without a path; --path prints the registry"
    # Usage: _ai_lessons_register MD JSON   |   _ai_lessons_register --path
    # Called by the comments stage after it writes MD. Whatever directory the review ran in
    # and wherever -o sent it, the file is found again by `ai lessons` (list, open, mark).
    # One line per file, the newest last; a file written again moves to the end.
    set -l base $XDG_DATA_HOME
    test -n "$base"; or set base ~/.local/share
    set -l registry $base/ai/reviews.jsonl
    if test "$argv[1]" = --path
        echo $registry
        return 0
    end
    set -l md (path resolve -- $argv[1])
    set -l json $argv[2]
    test -f "$md"; or return 0
    set -l root (jq -r '.repo.root // empty' $json 2>/dev/null)
    set -l origin (jq -r '.repo.origin // empty' $json 2>/dev/null)
    # A short name for the list: the repository's directory, else the origin's last part
    set -l project (path basename -- "$root")
    test -n "$root"; or set project (string replace -r '\.git/?$' '' -- "$origin" | string replace -r '.*[/:]' '')
    mkdir -p (path dirname -- $registry); or return 0
    set -l tmp (mktemp)
    test -f $registry; and jq -c --arg md $md 'select(.md != $md)' $registry >$tmp 2>/dev/null
    jq -cn --arg date (date '+%F %H:%M') --arg md $md --arg root "$root" --arg origin "$origin" --arg project "$project" \
        '{date: $date, md: $md, project: $project, root: $root, origin: $origin}' >>$tmp
    cat $tmp >$registry
    rm -f $tmp
end
