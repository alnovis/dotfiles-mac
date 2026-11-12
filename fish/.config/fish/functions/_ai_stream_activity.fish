function _ai_stream_activity --description "What a native driver's model does, from the stream it saves in DIR/stream: reading, thinking N or writing N (characters so far)"
    # The native drivers (_ai_provider_ollama, _ai_provider_openai) keep the raw stream in
    # AI_STREAM_DIR/stream while it arrives, so a run of theirs gets the same live line as a pi
    # run: "reading" until a token comes (a local model reads a big prompt for minutes), then
    # the characters of reasoning and of answer so far. ollama's NDJSON has .thinking and
    # .response; an OpenAI stream's "data: {...}" lines carry .choices[0].delta with
    # .reasoning_content (or .reasoning) and .content. The verify pass showed a fixed
    # "working... est 8m prefill" for 18 minutes, its reasoning never on stdout to count.
    set -l f $argv[1]/stream
    test -f $f; or return 1
    set -l n (jq -R -n -r '
        [inputs | ltrimstr("data: ") | fromjson? | (.choices[0]?.delta? // .) as $d
         | [($d.thinking // $d.reasoning_content // $d.reasoning // "" | if type == "string" then length else 0 end),
            ($d.response // $d.content // "" | if type == "string" then length else 0 end)]]
        | "\(map(.[0]) | add // 0) \(map(.[1]) | add // 0)"' $f 2>/dev/null | string split ' ')
    if test "$n[2]" -gt 0 2>/dev/null
        echo "writing $n[2]"
    else if test "$n[1]" -gt 0 2>/dev/null
        echo "thinking $n[1]"
    else
        # With the seconds the read is expected to take, when the driver knows them (the
        # third field of DIR/ctx, from _ai_ollama_prefill)
        set -l ctx (string split ' ' -- (string trim <$argv[1]/ctx 2>/dev/null))
        echo reading $ctx[3]
    end
end
