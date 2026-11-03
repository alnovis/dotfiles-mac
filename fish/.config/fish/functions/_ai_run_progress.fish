function _ai_run_progress --description "Draw an agentic pi run's live line every second until its pi process is gone (a separate process beside the run)"
    # Usage: _ai_run_progress SESSION_DIR T0 NAME WIDTH
    # Started by _ai_run_watched as its own fish process: the model must stay in the
    # foreground so Ctrl-C reaches it, and a fish function cannot run in the background. It
    # stops when the pi run that writes SESSION_DIR is gone — on Ctrl-C too, when the caller's
    # cleanup never runs — or when it never showed up within 30 s (not a pi run).
    set -l sdir $argv[1]
    set -l t0 $argv[2]
    set -l name $argv[3]
    set -l width $argv[4]
    set -l seen 0
    while true
        if pgrep -f -- "--session-dir $sdir" >/dev/null
            set seen 1
        else if test $seen -eq 1; or test (math (date +%s) - $t0) -gt 30
            break
        end
        set -l p (_ai_session_progress $sdir | string split \t)
        printf '\r\033[K%s' (_ai_progress_line "$name" (math (date +%s) - $t0) $width $p) >&2
        sleep 1
    end
end
