function _ai_run_progress --description "Draw an agentic pi run's live line every second while its pi process lives (a separate process beside the run)"
    # Usage: _ai_run_progress SESSION_DIR T0 NAME WIDTH
    # Started by _ai_run_watched as its own fish process: the model must stay in the
    # foreground so Ctrl-C reaches it, and a fish function cannot run in the background.
    # It follows pi by the pid _ai_agent_pi leaves in SESSION_DIR/pid and stops when that
    # process is gone — on Ctrl-C too, when the caller's cleanup never runs — or when no pid
    # shows up within 30 s (not a pi run). Not by its command line: pi rewrites it, and a
    # search for "--session-dir" found nothing, so the line froze at "turn 1 · 30s".
    set -l sdir $argv[1]
    set -l t0 $argv[2]
    set -l name $argv[3]
    set -l width $argv[4]
    set -l pid
    set -l window
    while true
        if test -z "$pid"
            test -s $sdir/pid; and set pid (string trim <$sdir/pid)
            test -z "$pid"; and test (math (date +%s) - $t0) -gt 30; and break
        else if not kill -0 $pid 2>/dev/null
            break
        end
        set -l p (_ai_session_progress $sdir | string split \t)
        # The model's context window, once its name is known: from pi's model config
        if test -z "$window"; and test -n "$p[4]"
            set -l pm (string split -m1 / -- $p[4])
            set window (jq -r --arg p $pm[1] --arg m $pm[2] \
                '.providers[$p].models[]? | select(.id == $m) | .contextWindow // empty' ~/.pi/agent/models.json 2>/dev/null)
            test -n "$window"; or set window none
        end
        set -l w $window
        test "$w" = none; and set w ""
        set -l fields
        # No session yet: only the time (the window would land in the turns' place)
        set -q p[1]; and set fields $p $w
        printf '\r\033[K%s' (_ai_progress_line "$name" (math (date +%s) - $t0) $width $fields) >&2
        sleep 1
    end
end
