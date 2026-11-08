function _ai_lessons --description "ai lessons: what a person said about review comments (Outcome marks), logged per project"
    # The feedback loop, phase 1: no model. A person marks each comment of a
    # <review>.comments.md in the editor (Outcome: + / - why / ~ / missed), `ai lessons mark`
    # appends the marks to the project's outcomes.jsonl, `ai lessons stats` counts them.
    # Per project and private: kept outside the repository (_ai_lessons_dir), so nothing
    # is committed by accident.
    if contains -- --help $argv; or contains -- -h $argv; or test (count $argv) -eq 0
        _ai_lessons_help
        return 0
    end

    switch "$argv[1]"
        case mark
            _ai_lessons_mark $argv[2..]
        case stats
            _ai_lessons_stats
        case path
            _ai_lessons_dir
        case edit
            _ai_lessons_edit
        case '*'
            set_color red
            echo "Unknown lessons subcommand: $argv[1]"
            set_color normal
            echo "Run 'ai lessons --help' for usage."
            return 1
    end
end

function _ai_lessons_help
    echo "Usage: ai lessons mark FILE   Log the Outcome marks of a <review>.comments.md"
    echo "       ai lessons stats       How right the reviews and their verify were, by model"
    echo "       ai lessons path        Where this project's lessons and outcomes are kept"
    echo "       ai lessons edit        Open this project's lessons.md in \$EDITOR"
    echo ""
    echo "Mark in the comments file, under each comment:"
    echo "  Outcome: +          right (posted, or fixed)"
    echo "  Outcome: - why      a false positive; say why in a few words"
    echo "  Outcome: ~          unsure, or does not matter"
    echo "Under 'Refuted by verify':"
    echo "  Outcome: +          verify was right to refute it"
    echo "  Outcome: missed     a real bug that verify refuted"
    echo "An unmarked '_' is skipped. Logged marks get '(logged)'; a comments file with marks"
    echo "not logged yet is not overwritten by a new comments stage."
    echo ""
    echo "Per project, outside its repository: ~/.local/share/ai/lessons/<origin URL>/"
    echo "(\$XDG_DATA_HOME if set); lessons_dir in the project's .ai/config puts them elsewhere."
    echo "mark finds the project from the file, run from anywhere: the repository the comments"
    echo "stage recorded in <review>.comments.json. stats, path and edit: the current directory's."
end

function _ai_lessons_dir --description "A project's lessons directory: lessons_dir from its config, else <data>/ai/lessons/<the origin URL, or the repository's path>"
    # The project: --root DIR (a repository), else --origin URL (its repository is gone:
    # a removed worktree), else the repository of the current directory
    argparse 'root=' 'origin=' -- $argv; or return 1
    set -l root
    set -l url $_flag_origin
    if set -q _flag_root
        set root (git -C $_flag_root rev-parse --show-toplevel 2>/dev/null)
    else if not set -q _flag_origin
        set root (git rev-parse --show-toplevel 2>/dev/null)
    end
    if test -z "$root"; and test -z "$url"
        echo "lessons: not in a git repository — lessons are kept per project" >&2
        return 1
    end
    if test -n "$root"
        # lessons_dir from the project's own .ai/config, relative to its root
        set -l dir
        if set -q _flag_root
            test -f $root/.ai/config; and set dir (_ai_config_read_file $root/.ai/config lessons_dir 2>/dev/null)
        else
            set dir (_ai_config_read lessons_dir 2>/dev/null)
        end
        if test -n "$dir"
            string match -q -- '/*' $dir; or set dir $root/$dir
            echo $dir
            return 0
        end
        set url (git -C $root remote get-url origin 2>/dev/null)
    end
    set -l base $XDG_DATA_HOME
    test -n "$base"; or set base ~/.local/share
    # One key for every clone and worktree of a project: its origin, without scheme, user
    # and .git (git@host:g/p.git and https://host/g/p are both host/g/p)
    set -l key
    if test -n "$url"
        set key (string replace -r '^[a-z+]+://' '' -- $url | string replace -r '^[^@/]+@' '' \
            | string replace -r '^([^/:]+):(?!\d+/)' '$1/' | string replace -r '\.git/?$' '' \
            | string replace -r '/+$' '')
    else
        set key local(string replace -r '/+$' '' -- $root)
    end
    echo $base/ai/lessons/$key
end

function _ai_lessons_edit --description "Open this project's lessons.md in \$EDITOR, from a template the first time"
    set -l dir (_ai_lessons_dir); or return 1
    set -l file $dir/lessons.md
    if not test -f $file
        mkdir -p $dir; or return 1
        printf '%s\n' "# Lessons for this project" "" \
            "Rules for its reviews, one line each, kept by hand. Say where a rule came from" \
            "(the outcomes in outcomes.jsonl) and where it holds (a path, a pattern)." "" \
            "## Not bugs here" "" "## Look for" "" "## Conventions" >$file
    end
    set -l editor $EDITOR
    test -n "$editor"; or set editor nvim
    $editor $file
end

function _ai_lessons_mark --description "Append the filled Outcome marks of a comments file to the project's outcomes.jsonl; mark them (logged)"
    argparse 'dry-run' -- $argv; or return 1
    set -l md $argv[1]
    if test -z "$md"; or not test -f "$md"
        echo "lessons: mark needs a <review>.comments.md (got: '$md')" >&2
        return 1
    end
    set md (realpath $md)

    # Its siblings: review.comments.md → review.md, review.verify.md, review.comments.json
    set -l stem (string replace -r '\.comments\.md$' '' -- $md)
    set -l json $stem.comments.json

    # The project, from wherever this runs: the repository the comments stage recorded in
    # the JSON; its origin when that repository is gone (a removed worktree); the
    # repository the file sits in; the current directory's
    set -l where
    set -l jroot (jq -r '.repo.root // empty' $json 2>/dev/null)
    set -l jorigin (jq -r '.repo.origin // empty' $json 2>/dev/null)
    if test -n "$jroot"; and git -C $jroot rev-parse --git-dir >/dev/null 2>&1
        set where --root $jroot
    else if test -n "$jorigin"
        set where --origin $jorigin
    else if git -C (path dirname -- $md) rev-parse --git-dir >/dev/null 2>&1
        set where --root (path dirname -- $md)
    else if not git rev-parse --git-dir >/dev/null 2>&1
        echo "lessons: cannot tell which project $md is about: its comments JSON names no repository" >&2
        echo "  (made before ai lessons existed?), and neither it nor the current directory is in one." >&2
        echo "  Run it from the project's repository." >&2
        return 1
    end
    set -l dir (_ai_lessons_dir $where); or return 1
    set -l log $dir/outcomes.jsonl
    set -l review $stem.md
    set -l verify (_ai_verify_output_path $review)
    set -l range ""
    test -s $json; and set range (jq -r 'if .base_sha then "\(.base_sha[0:7])..\(.head_sha[0:7])" else "" end' $json 2>/dev/null)
    # Who reviewed and verified: the Run: lines at the end of each file
    set -l rmodel (_ai_lessons_run_model $review Review)
    set -l vmodel (_ai_lessons_run_model $verify Verify)

    # One row per Outcome line: NR, section, findings, path, line, severity, status, title, value
    set -l rows (awk '
        BEGIN { OFS = "\t" }
        /^## Refuted by verify/ { sect = "refuted"; path = ""; next }
        /^## / { sect = "comment"; path = substr($0, 4); next }
        sect == "comment" && /^### / {
            n = split(substr($0, 5), p, / \| /)
            line = ""; if (p[1] ~ /^Line [0-9]+/) { line = p[1]; sub(/^Line /, "", line); sub(/[^0-9].*$/, "", line) }
            sev = p[2]; status = ($0 ~ / \| uncertain/) ? "uncertain" : "confirmed"
            fids = (p[n] ~ /^F[0-9]+(, F[0-9]+)*$/) ? p[n] : ""
            gsub(/, /, ",", fids)
            title = ""; body = 1
            next
        }
        # A comment with no finding number is known by the first line of its text
        sect == "comment" && /^```/ { fence = !fence; next }
        sect == "comment" && body && !fence && /^[^>[:space:]]/ && !/^Outcome:/ {
            title = substr($0, 1, 120); body = 0
        }
        sect == "refuted" && /^- / {
            title = substr($0, 3); sub(/: refuted[^:]*$/, "", title)
            fids = ""; if (match(title, /\[?F[0-9]+\]?/) == 1) { fids = substr(title, RSTART, RLENGTH); gsub(/[\[\]]/, "", fids) }
            line = ""; sev = ""; status = "refuted"
            next
        }
        /^[[:space:]]*Outcome:/ {
            v = $0; sub(/^[[:space:]]*Outcome:[[:space:]]*/, "", v); sub(/[[:space:]]+$/, "", v)
            print NR, sect, fids, path, line, sev, status, title, v
        }' $md)

    set -l errors
    set -l take
    set -l outs
    set -l logged 0
    set -l blank 0
    for r in $rows
        set -l f (string split \t -- $r)
        set -l v $f[9]
        if test -z "$v"; or test "$v" = _
            set blank (math $blank + 1)
            continue
        end
        if string match -q -- '*(logged)' $v
            set logged (math $logged + 1)
            continue
        end
        set -l outcome
        set -l reason ""
        switch $v
            case +
                set outcome right
            case '~'
                set outcome unsure
            case missed
                set outcome missed
                test "$f[2]" = refuted; or set -a errors "$md:$f[1]: 'missed' is for a refuted finding; a comment is + or - why"
            case '-*'
                set outcome wrong
                set reason (string replace -r '^-\s*' '' -- $v)
                test "$f[2]" = comment; or set -a errors "$md:$f[1]: a refuted finding is + (verify was right) or missed"
                test -n "$reason"; or set -a errors "$md:$f[1]: '-' needs a reason: '- why it is not a bug'"
            case '*'
                set -a errors "$md:$f[1]: '$v' is not a mark (+, - why, ~, missed)"
        end
        set -a take "$r"\t$outcome\t$reason
        set -a outs $outcome
    end
    if set -q errors[1]
        set_color red >&2
        printf '%s\n' $errors >&2
        set_color normal >&2
        echo "lessons: nothing logged — fix the marks above and run it again" >&2
        return 1
    end
    if not set -q take[1]
        echo "lessons: no new marks in $md ($blank not marked, $logged logged before)"
        return 0
    end

    # The title: a refuted entry's own; a comment's, the review's line of its first [Fn],
    # else the first line of the comment's text
    set -l entries
    set -l keys
    test -s $log; and set keys (jq -r '.key' $log 2>/dev/null)
    set -l dup 0
    set -l nrs
    for t in $take
        set -l f (string split \t -- $t)
        set -l title $f[8]
        set -l first (string split , -- $f[3])[1]
        # The review's own line wins over the comment's text: it is what the finding said
        if test "$f[2]" = comment; and test -n "$first"; and test -f $review
            set -l own (string match -r -e -- "\[$first\]" <$review | head -1 \
                | string replace -r '^\s*([-*]|\d+\.|#+)?\s*\[F\d+\]\s*' '' | string replace -a '**' '')
            test -n "$own"; and set title $own
        end
        set -l key "$range|$f[2]|$f[3]|$f[4]:$f[5]|$title"
        if contains -- $key $keys
            set dup (math $dup + 1)
        else
            set -a keys $key
            set -a entries (jq -cn --arg key $key --arg date (date +%F) --arg file $md --arg range $range \
                --arg kind $f[2] --arg findings $f[3] --arg path $f[4] --arg line $f[5] \
                --arg severity $f[6] --arg status $f[7] --arg title "$title" \
                --arg outcome $f[10] --arg reason "$f[11]" --arg review_model "$rmodel" --arg verify_model "$vmodel" \
                '{key: $key, date: $date, file: $file, range: $range, kind: $kind,
                  findings: ($findings | split(",") | map(select(. != ""))), path: $path,
                  line: ($line | tonumber? // null), severity: $severity, status: $status, title: $title,
                  outcome: $outcome, reason: $reason, review_model: $review_model, verify_model: $verify_model}')
        end
        set -a nrs $f[1]
    end

    set -l counts (printf '%s\n' $outs | sort | uniq -c | awk '{ printf "%s%s %s", (NR > 1 ? ", " : ""), $1, $2 }')
    if set -q _flag_dry_run
        echo "would log "(count $entries)" outcome(s) to $log: $counts"
        printf '%s\n' $entries
        return 0
    end
    mkdir -p $dir; or return 1
    test (count $entries) -gt 0; and printf '%s\n' $entries >>$log
    # The marks taken get "(logged)": a second run skips them, and a new comments stage may
    # overwrite the file (_ai_comments_md_guard)
    set -l tmp (mktemp)
    awk -v nrs=","(string join , -- $nrs)"," 'index(nrs, "," NR ",") { $0 = $0 " (logged)" } 1' $md >$tmp
    and cat $tmp >$md
    rm -f $tmp
    set -l note ""
    test $dup -gt 0; and set note "; $dup already in the log"
    echo "lessons: logged "(count $entries)" outcome(s) to $log: $counts$note"
end

function _ai_lessons_run_model --description "provider/model of a review or verify file, from its Run: lines (several runs: each once)" --argument-names file stage
    test -f "$file"; or return 0
    string match -r -g -- "^Run: (?:\[[^\]]*\] )?$stage(?: ×\d+)?(?: run \d+/\d+)? - (.+?) - (.+?) \|" <$file \
        | paste - - | string replace \t / | sort -u | string join ', '
    return 0
end

function _ai_lessons_stats --description "How right the reviews and verify were, from this project's outcomes.jsonl"
    set -l dir (_ai_lessons_dir); or return 1
    set -l log $dir/outcomes.jsonl
    if not test -s $log
        echo "lessons: no outcomes yet for this project ($log); mark a comments file, then: ai lessons mark FILE"
        return 0
    end
    _ai_ui_heading Outcomes (jq -s -r '"\(length) from \(map(.date) | min) to \(map(.date) | max)"' $log)
    _ai_ui_kv log $log

    # Review: of the comments a person judged (+ or -), how many were right
    _ai_ui_heading "Review comments" "right / (right + wrong), by the review's model"
    jq -s -r '[.[] | select(.kind == "comment")] | group_by(.review_model)[]
        | (map(select(.outcome == "right")) | length) as $r
        | (map(select(.outcome == "wrong")) | length) as $w
        | (map(select(.outcome == "unsure")) | length) as $u
        | [(.[0].review_model | if . == "" then "(unknown)" else . end),
           "\($r) right, \($w) wrong, \($u) unsure"
           + (if $r + $w > 0 then " | precision \((100 * $r / ($r + $w)) | round)%" else "" end)] | @tsv' $log \
        | while read -l -d \t m v
            _ai_ui_kv $m $v
        end

    # Verify: what it let through and what it threw out wrongly
    _ai_ui_heading Verify "a wrong comment got past it; a missed bug it refuted"
    jq -s -r 'group_by(.verify_model)[]
        | [(.[0].verify_model | if . == "" then "(unknown)" else . end),
           "\(map(select(.kind == "comment" and .outcome == "wrong")) | length) false positive(s) let through, "
           + "\(map(select(.kind == "refuted" and .outcome == "missed")) | length) real bug(s) refuted, "
           + "\(map(select(.kind == "refuted" and .outcome == "right")) | length) refuted rightly"] | @tsv' $log \
        | while read -l -d \t m v
            _ai_ui_kv $m $v
        end

    # The reasons: the raw material of lessons.md
    set -l wrong (jq -r 'select(.outcome == "wrong") | "\(.date)  \(.path)\(if .line then ":\(.line)" else "" end)  \(.reason)"' $log | tail -10)
    if set -q wrong[1]
        _ai_ui_heading "False positives" "the last "(count $wrong)", with why"
        printf '  %s\n' $wrong
    end
    set -l missed (jq -r 'select(.outcome == "missed") | "\(.date)  \(.title)"' $log | tail -10)
    if set -q missed[1]
        _ai_ui_heading "Refuted, but real" "the last "(count $missed)
        printf '  %s\n' $missed
    end
end
