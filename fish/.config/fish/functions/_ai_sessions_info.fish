function _ai_sessions_info --description "Show session NAME metadata + token statistics" --argument-names name
    if test -z "$name"
        set_color red
        echo "Error: session name required — ai sessions info NAME"
        set_color normal
        return 1
    end

    set -l file (_ai_session_file $name)
    if test -z "$file"
        set_color red
        echo "Error: session '$name' not found"
        set_color normal
        return 1
    end

    set -l meta (_ai_session_meta $file)
    set -l parts (string split "|" $meta)
    set -l created $parts[2]
    set -l last_ts $parts[3]
    set -l turns $parts[4]
    set -l models $parts[5]
    set -l tok_in $parts[6]
    set -l tok_out $parts[7]

    set -l scope global
    if string match -q "$HOME/.config/ai/sessions/*" $file
        # global
    else
        set scope project
    end

    set_color cyan
    echo "$name"
    set_color normal
    echo "  Path:    $file"
    echo "  Scope:   $scope"
    echo "  Created: $created"
    echo "  Updated: $last_ts ("(_ai_relative_time $last_ts)")"
    echo "  Turns:   $turns"
    echo "  Tokens:  $tok_in input / $tok_out output"
    echo "  Model:   $models"
end
