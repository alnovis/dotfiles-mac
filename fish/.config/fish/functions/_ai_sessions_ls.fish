function _ai_sessions_ls --description "List sessions (project walk-up + global). --archived shows archived; --all shows both."
    argparse 'a/all' 'archived' -- $argv; or return 1

    set -l show_active 1
    set -l show_archived 0
    if set -q _flag_all
        set show_archived 1
    else if set -q _flag_archived
        set show_active 0
        set show_archived 1
    end

    set -l proj_dir

    set -l dir $PWD
    while true
        if test "$dir" = "$HOME"; or test "$dir" = /
            break
        end
        if test -d "$dir/.ai/sessions"
            set proj_dir "$dir/.ai/sessions"
            break
        end
        if test -d "$dir/.git"
            break
        end
        set dir (dirname $dir)
    end

    set -l global_dir ~/.config/ai/sessions

    set -l shown 0

    if test -n "$proj_dir"
        if test $show_active -eq 1; and count $proj_dir/*.jsonl >/dev/null 2>&1
            set_color cyan
            echo "[project] $proj_dir"
            set_color normal
            _ai_sessions_ls_print $proj_dir
            set shown 1
            echo
        end
        if test $show_archived -eq 1; and count $proj_dir/archived/*.jsonl >/dev/null 2>&1
            set_color brblack
            echo "[project archived] $proj_dir/archived"
            set_color normal
            _ai_sessions_ls_print $proj_dir/archived
            set shown 1
            echo
        end
    end

    if test -d $global_dir
        if test $show_active -eq 1; and count $global_dir/*.jsonl >/dev/null 2>&1
            set_color cyan
            echo "[global] $global_dir"
            set_color normal
            _ai_sessions_ls_print $global_dir
            set shown 1
            echo
        end
        if test $show_archived -eq 1; and count $global_dir/archived/*.jsonl >/dev/null 2>&1
            set_color brblack
            echo "[global archived] $global_dir/archived"
            set_color normal
            _ai_sessions_ls_print $global_dir/archived
            set shown 1
            echo
        end
    end

    if test $shown -eq 0
        echo "No sessions. Create one: ai chat --session NAME"
    end

    set_color brblack
    echo "Claude conversations: use 'claude --resume' / 'claude -c' (managed by Claude CLI)"
    set_color normal
end

function _ai_sessions_ls_print --argument-names dir
    set -l last_name ""
    if test -f $dir/.last
        set last_name (cat $dir/.last)
    end

    for file in $dir/*.jsonl
        if not test -f $file
            continue
        end
        set -l meta (_ai_session_meta $file)
        set -l parts (string split "|" $meta)
        set -l name $parts[1]
        set -l last_ts $parts[3]
        set -l turns $parts[4]
        set -l models $parts[5]

        # Detect pin from any config record with pinned:true
        set -l pinned (jq -s '[.[] | select(.t == "config" and .pinned == true)] | length' $file 2>/dev/null)
        set -l pin_marker ""
        if test -n "$pinned"; and test "$pinned" -gt 0
            set pin_marker " [pinned]"
        end

        set -l marker "  "
        if test "$name" = "$last_name"
            set_color yellow
            set marker "> "
        end

        printf "%s%-24s %4s turns   %-10s   ollama / %s%s\n" $marker $name $turns (_ai_relative_time $last_ts) $models $pin_marker
        set_color normal
    end
end
