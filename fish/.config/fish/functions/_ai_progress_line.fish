function _ai_progress_line --description "The live line of an agentic run: MODEL | turn N | PHASE | ctx USED/WINDOW | ELAPSED | LAST TOOL [| no answer for M], cut to WIDTH"
    # Usage: _ai_progress_line NAME ELAPSED_S WIDTH [TURNS TOOL IDLE_S MODEL CTX PHASE WINDOW]
    # TURNS…PHASE come from _ai_session_progress, WINDOW is the model's context window from
    # the runner config; without them only the time — a runner with no session.
    #   ollama · qwen3.8:27b | turn 9 | model… | ctx 57k/131k | 4m 12s | read RouteStage.scala
    # The fields of the old native loop's line (model, turn, phase, context, time), plus the
    # last tool call; while a tool runs it is the phase. One line: a wrapped one cannot be
    # redrawn with \r, so it is cut to the width — the last tool, at the end, gives way.
    # After 300 s of a quiet session it says so in yellow: the hang the eval only found by
    # reading the session by hand.
    set -l name $argv[1]
    set -l elapsed $argv[2]
    set -l width $argv[3]
    set -l warn ""
    if test -n "$argv[6]"; and test "$argv[6]" -ge 300
        set warn " | no answer for "(_ai_ui_duration $argv[6])
    end
    set -l avail (math "max(20, $width - 3 - "(string length -- "$name$warn")")")
    set -l head
    set -l phase
    set -l tail (_ai_ui_duration $elapsed)
    set -l tool
    if test -n "$argv[4]"
        test -n "$argv[7]"; and set -a head (string replace / ' · ' -- $argv[7])
        set -a head "turn "(math $argv[4] + 1)
        set phase model…
        string match -q 'tool *' -- "$argv[9]"; and set phase (string sub -s 6 -- $argv[9])…
        if test -n "$argv[8]"; and test "$argv[8]" -gt 0
            set -l ctx "ctx "(_ai_k $argv[8])
            test -n "$argv[10]"; and set ctx "$ctx/"(_ai_k $argv[10])
            set -p tail $ctx
        end
        test -n "$argv[5]"; and test "$phase" = model…; and set tool $argv[5]
    else
        set phase working…
    end
    # Too long: the last tool goes first, then the phase (a long tool argument) is cut, then
    # the model's name; the turn, the context and the time stay
    set -l line (string join ' | ' -- $head $phase $tail $tool)
    if test (string length -- $line) -gt $avail
        set line (string join ' | ' -- $head $phase $tail)
    end
    if test (string length -- $line) -gt $avail
        set -l room (math "max(8, $avail - "(string length -- (string join ' | ' -- $head $tail))" - 3)")
        set phase (string shorten -m $room -- $phase)
        set line (string join ' | ' -- $head $phase $tail)
    end
    if test (string length -- $line) -gt $avail; and set -q head[2]
        set line (string join ' | ' -- $head[2..] $phase $tail)
    end
    set line (string shorten -m $avail -- $line)
    printf '  %s%s' $name $line
    test -n "$warn"; and printf '%s%s%s' (set_color yellow) $warn (set_color normal)
    return 0
end

function _ai_k --description "A token count as 950, 57k, 1.2M"
    if test $argv[1] -ge 1000000
        echo (math -s1 "$argv[1] / 1000000")M
    else if test $argv[1] -ge 1000
        echo (math "round($argv[1] / 1000)")k
    else
        echo $argv[1]
    end
end
