function _ai_sessions_show --description "Render session NAME as markdown" --argument-names name
    if test -z "$name"
        set_color red
        echo "Error: session name required — ai sessions show NAME"
        set_color normal
        return 1
    end

    set -l file (_ai_session_file $name)
    if test -z "$file"
        set_color red
        echo "Error: session '$name' not found"
        set_color normal
        echo "Available: "(_ai_session_names | string join ", ")
        return 1
    end

    set -l meta (_ai_session_meta $file)
    set -l parts (string split "|" $meta)
    set -l created $parts[2]
    set -l last_ts $parts[3]
    set -l turns $parts[4]
    set -l models $parts[5]

    set_color cyan
    echo "# Session: $name"
    set_color normal
    echo "Path:    $file"
    echo "Created: $created"
    echo "Updated: $last_ts ("(_ai_relative_time $last_ts)")"
    echo "Turns:   $turns"
    echo "Model:   $models"
    echo
    echo "---"
    echo

    jq -r '
        if .t == "system" then "## System\n\(.content)\n"
        elif .t == "user" then "## User\n\(.content)\n"
        elif .t == "assistant" then "## Assistant (\(.model // "?"))\n\(.content)\n"
        elif .t == "summary" then "## Summary (covers turns 1..\(.covers // "?"))\n\(.content)\n"
        else empty end
    ' $file
end
