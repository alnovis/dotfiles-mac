function _ai_session_summarize --description "Generate a structured fact list from MESSAGES via ollama; outputs summary text" --argument-names model messages_json
    # Load prompt template (overridable) with fallback
    set -l template ~/.config/fish/prompts/meta-session-summary.md
    set -l prompt
    if test -f $template
        set prompt (cat $template | string collect)
    else
        set prompt "You will produce a structured fact list from a chat conversation. The fact list will be the ONLY context for continuing — anything you omit is lost. Preserve names, file paths, code, decisions, conventions, user preferences, and open items. Keep identifiers verbatim. Bullet list, no preamble, no markdown headers. If unsure, keep it.

Conversation:"
    end

    set -l transcript (echo $messages_json | jq -r '.[] | (.role | ascii_upcase) + ": " + .content' | string collect)

    set -l full_prompt "$prompt
$transcript

Facts:"

    set -l body (jq -nc --arg m "$model" --arg p "$full_prompt" \
        '{model: $m, messages: [{role: "user", content: $p}], stream: false}')

    curl -s -X POST http://localhost:11434/api/chat \
        -H 'Content-Type: application/json' \
        -d "$body" 2>/dev/null \
        | jq -r '.message.content // empty' 2>/dev/null
end
