function _ai_pipe_input --description "Emit prompt then pass through stdin if piped"
    set -l prompt $argv[1]
    if test -n "$prompt"
        echo $prompt
        echo
    end
    if not isatty stdin
        cat
    end
end
