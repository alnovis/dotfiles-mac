function _ai_sessions_search --description "Search QUERY across session messages; case-insensitive substring"
    argparse 'name=' 'since=' 'a/all' 'archived' 'regex' -- $argv; or return 1

    set -l query $argv[1]
    if test -z "$query"
        set_color red
        echo "Error: query required — ai sessions search QUERY [--name PAT] [--since DATE] [--archived|--all]"
        set_color normal
        return 1
    end

    set -l show_archived 0
    set -q _flag_archived; and set show_archived 1
    set -q _flag_all; and set show_archived 1

    set -l name_pat $_flag_name
    set -l since_ts
    if set -q _flag_since
        set since_ts (date -j -f "%Y-%m-%d" "$_flag_since" +%s 2>/dev/null)
        if test -z "$since_ts"
            set_color red
            echo "Error: --since expects YYYY-MM-DD"
            set_color normal
            return 1
        end
    end

    # Collect candidate dirs
    set -l dirs

    set -l dir $PWD
    while true
        if test "$dir" = "$HOME"; or test "$dir" = /
            break
        end
        if test -d "$dir/.ai/sessions"
            set -a dirs "$dir/.ai/sessions:project"
            if test $show_archived -eq 1; and test -d "$dir/.ai/sessions/archived"
                set -a dirs "$dir/.ai/sessions/archived:project-archived"
            end
            break
        end
        if test -d "$dir/.git"
            break
        end
        set dir (dirname $dir)
    end

    if test -d ~/.config/ai/sessions
        set -a dirs ~/.config/ai/sessions:global
        if test $show_archived -eq 1; and test -d ~/.config/ai/sessions/archived
            set -a dirs ~/.config/ai/sessions/archived:global-archived
        end
    end

    set -l total_sessions 0
    set -l total_matches 0
    set -l matched_sessions 0

    for entry in $dirs
        set -l parts (string split ":" $entry)
        set -l d $parts[1]
        set -l scope $parts[2]

        for file in $d/*.jsonl
            if not test -f $file
                continue
            end

            set -l name (basename $file .jsonl)

            # Filter by --name pattern (substring)
            if test -n "$name_pat"; and not string match -qi "*$name_pat*" -- $name
                continue
            end

            # Filter by --since
            if test -n "$since_ts"
                set -l meta (_ai_session_meta $file)
                set -l mparts (string split "|" $meta)
                set -l last_iso $mparts[3]
                set -l last_unix (date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_iso" +%s 2>/dev/null)
                if test -n "$last_unix"; and test "$last_unix" -lt "$since_ts"
                    continue
                end
            end

            set total_sessions (math $total_sessions + 1)

            # Find matches (case-insensitive substring on .content for user/assistant)
            set -l hits (jq -sr --arg q "$query" '
                [.[] | select(.t == "user" or .t == "assistant")] | to_entries | map(
                    select(.value.content // "" | ascii_downcase | contains($q | ascii_downcase))
                ) | .[] | "\(.key+1)|\(.value.t)|\(.value.content)"
            ' $file 2>/dev/null)

            set -l hit_count (count $hits)
            if test $hit_count -eq 0
                continue
            end

            set matched_sessions (math $matched_sessions + 1)
            set total_matches (math $total_matches + $hit_count)

            set -l meta (_ai_session_meta $file)
            set -l mparts (string split "|" $meta)
            set -l last_ts $mparts[3]

            set_color cyan
            echo "$name ($scope, "(_ai_relative_time $last_ts)"):"
            set_color normal

            for hit in $hits
                set -l h (string split -m 2 "|" $hit)
                set -l idx $h[1]
                set -l role $h[2]
                set -l content $h[3]
                # Truncate content to ~80 chars; collapse newlines
                set -l preview (echo $content | tr '\n' ' ' | string sub --length 80)
                printf "  Turn %3s (%s): %s\n" $idx $role $preview
            end
            echo
        end
    end

    set_color brblack
    if test $total_matches -eq 0
        echo "No matches for '$query' across $total_sessions session(s)."
    else
        echo "$matched_sessions of $total_sessions session(s) matched, $total_matches matches total."
    end
    set_color normal
end
