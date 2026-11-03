function _ai_session_progress --description "Where an agentic pi run is, from its session dir: TURNS<TAB>LAST TOOL<TAB>SECONDS SINCE THE SESSION LAST CHANGED"
    # pi writes the session file entry by entry while it runs (_ai_agent_pi gives it the dir),
    # so the live line can say what the run is doing: its turn, its last tool call ("read
    # RouteStage.scala"), and how long the model has been quiet — a provider that hangs shows
    # as a growing idle time instead of a silent heading for half an hour.
    # grep, not jq over the file: it is read every second and can be megabytes.
    set -l f (path filter -f $argv[1]/*.jsonl)[1]
    test -n "$f"; or return 1
    set -l turns (grep -c '"role":"assistant"' $f)
    set -l tool (grep '"type":"toolCall"' $f | tail -1 | jq -r '
        [.message.content[]? | select(.type == "toolCall")] | last
        | .name + " " + ((.arguments.path // .arguments.pattern // "") | tostring | split("/") | last | .[0:40])
    ' 2>/dev/null | string trim)
    printf '%s\t%s\t%s\n' $turns "$tool" (path mtime --relative $f)
end
