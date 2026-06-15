function _ai_session_messages_json --description "Read JSONL session FILE and emit messages array JSON for ollama /api/chat" --argument-names file
    if not test -f $file
        echo "[]"
        return
    end

    # Filter to relevant message types and reshape to {role,content}.
    # 'summary' rows fold in as a system-role hint to keep the model on track.
    jq -sc '[ .[] |
        if .t == "system" or .t == "user" or .t == "assistant"
            then {role: .t, content: .content}
        elif .t == "summary"
            then {role: "system", content: ("Summary of earlier conversation: " + .content)}
        else empty end ]' $file
end
