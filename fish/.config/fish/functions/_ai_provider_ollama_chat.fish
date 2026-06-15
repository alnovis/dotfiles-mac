function _ai_provider_ollama_chat --description "Stream chat completion via Ollama /api/chat; prints response, captures meta to --meta-file"
    # Usage: _ai_provider_ollama_chat --model M --messages JSON [--meta-file FILE]
    # MESSAGES is a JSON array string. Streams response to stdout. Captures full
    # content + token usage to meta-file (JSON: {content, usage:{eval_count,prompt_eval_count}}).

    argparse 'model=' 'messages=' 'meta-file=' -- $argv; or return 1

    set -l model $_flag_model
    set -l messages $_flag_messages
    set -l meta_file $_flag_meta_file

    set -l body (jq -nc --arg model "$model" --argjson messages "$messages" '{model:$model, messages:$messages, stream:true}')

    set -l buf_file (mktemp -t ai-chat-buf.XXXXX)
    set -l usage_file (mktemp -t ai-chat-usage.XXXXX)

    # Stream: each line is a JSON chunk. Extract .message.content, print as it arrives.
    curl -sN -X POST http://localhost:11434/api/chat \
        -H 'Content-Type: application/json' \
        -d "$body" | while read -l line
        test -z "$line"; and continue

        set -l content (echo $line | jq -r '.message.content // empty')
        if test -n "$content"
            printf '%s' "$content"
            printf '%s' "$content" >>$buf_file
        end

        set -l done (echo $line | jq -r '.done // false')
        if test "$done" = true
            echo $line | jq -c '{eval_count, prompt_eval_count, total_duration}' >$usage_file
        end
    end
    echo

    if test -n "$meta_file"
        set -l full_content (cat $buf_file)
        set -l usage (cat $usage_file 2>/dev/null; or echo "{}")
        jq -nc --arg c "$full_content" --argjson u "$usage" '{content:$c, usage:$u}' >$meta_file
    end

    rm -f $buf_file $usage_file
end
