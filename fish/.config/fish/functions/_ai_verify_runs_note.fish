function _ai_verify_runs_note --description "The Saved line's note on verify runs: 'K/N answered[, M with numbered verdicts], majority above'"
    # Usage: _ai_verify_runs_note N RUN_FILE...
    # Answered is not judged: a run whose verdicts carry no finding numbers gives the vote
    # nothing (_ai_verify_keyed), so a wall of UNCERTAIN is explained right there.
    set -l n $argv[1]
    set -l files $argv[2..]
    set -l keyed 0
    for f in $files
        test (_ai_verify_keyed $f) -gt 0; and set keyed (math $keyed + 1)
    end
    set -l note (count $files)"/$n answered"
    test $keyed -lt (count $files); and set note "$note, $keyed with numbered verdicts"
    echo "$note, majority above"
end
