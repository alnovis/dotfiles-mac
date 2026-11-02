function _ai_runs_failed_lines --description "The \"failed\" lines of the Saved block for the runs that failed (\$__ai_runs_failed entries), in yellow"
    # Under the files of the same stage: each run's lines have scrolled away by then
    set -q argv[1]; or return 0
    set_color yellow
    _ai_ui_kv failed $argv[1]
    for f in $argv[2..]
        _ai_ui_kv "" $f
    end
    set_color normal
end
