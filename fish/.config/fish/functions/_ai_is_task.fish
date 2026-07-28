function _ai_is_task --description "True if the argument is a known AI task, a comma-list of them, or 'all'"
    test -z "$argv[1]"; and return 1
    test "$argv[1]" = all; and return 0
    set -l valid (_ai_tasks)
    for t in (string split , -- $argv[1])
        contains -- $t $valid; or return 1
    end
    return 0
end
