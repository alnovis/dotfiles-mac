function _ai_review_context_budget --description "Line budget for embedding whole files: --context-lines > config key > default"
    # Args: git|dir [FLAG_VALUE]
    #   git  changed files in git mode — config key context_lines, default 2000
    #   dir  a directory target's files — config key dir_context_lines, default 10000
    # Prints the budget (0 = embed nothing); errors on a value that is not a non-negative
    # integer, naming where it came from.
    set -l mode $argv[1]
    set -l key context_lines
    set -l default 2000
    if test "$mode" = dir
        set key dir_context_lines
        set default 10000
    end

    set -l value $argv[2]
    set -l origin --context-lines
    if test -z "$value"
        set value (_ai_config_read $key)
        set origin "config key $key"
    end
    if test -z "$value"
        echo $default
        return 0
    end
    if not string match -qr '^[0-9]+$' -- $value
        set_color red >&2
        echo "Error: $origin must be a non-negative integer (got '$value')" >&2
        set_color normal >&2
        return 1
    end
    echo $value
end
