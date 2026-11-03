function _ai_progress_line --description "The live line of an agentic run: [NAME] turn N · ELAPSED · LAST TOOL [· no answer for M], cut to WIDTH"
    # Usage: _ai_progress_line NAME ELAPSED_S WIDTH [TURNS TOOL IDLE_S]  (the last three from
    # _ai_session_progress; without them only the time — a runner with no session)
    # One line: a wrapped one cannot be redrawn with \r, so it is cut to the width — the tool
    # last, the part that gives way. After 300 s of a quiet session it says so, in yellow —
    # the hang the eval only found by reading the session by hand.
    set -l name $argv[1]
    set -l elapsed $argv[2]
    set -l width $argv[3]
    set -l parts
    if test -n "$argv[4]"
        set -a parts "turn "(math $argv[4] + 1) (_ai_ui_duration $elapsed)
        test -n "$argv[5]"; and set -a parts $argv[5]
    else
        set -a parts working… (_ai_ui_duration $elapsed)
    end
    set -l line (string join ' · ' -- $parts)
    set -l warn ""
    set -l idle_warn 300
    if test -n "$argv[6]"; and test "$argv[6]" -ge $idle_warn
        set warn " · no answer for "(_ai_ui_duration $argv[6])
    end
    set line (string shorten -m (math "max(20, $width - 3 - "(string length -- "$name$warn")")") -- $line)
    printf '  %s%s' $name $line
    test -n "$warn"; and printf '%s%s%s' (set_color yellow) $warn (set_color normal)
    return 0
end
