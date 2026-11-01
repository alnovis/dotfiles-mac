function _ai_provider_openai --description "Native driver: one OpenAI chat-completions call to a runner-configured provider (litellm, …), no agent in between"
    # Contract (called by _ai_run, like _ai_provider_ollama):
    #   --provider P            provider as the runner's config names it (endpoint, key, limits)
    #   --model M               model id (the runner's default for P when empty)
    #   --no-think / --think    a cloud model decides itself; --no-think is not supported
    #   --thinking-output F     the reasoning (delta.reasoning_content) goes to F
    #   --usage-output F        the final usage object (tokens, cost) goes to F as JSON
    #   --interactive           no REPL here — handed to the runner
    #
    # Why not the runner: a single call needs no agent, and pi in between meant silent
    # defaults (tiny context for an unregistered model → empty review), its own system
    # prompt leaking in, no reasoning sidecar, no usage. Reads the prompt from stdin,
    # streams the answer to stdout.
    argparse 'provider=' 'model=' 'think' 'no-think' 'thinking-output=' 'usage-output=' 'interactive' -- $argv; or return 1
    set -l provider $_flag_provider
    set -l model $_flag_model
    set -l runner (_ai_default_agent); or return 1

    if set -q _flag_interactive
        set -l args --interactive --provider $provider --tools none
        test -n "$model"; and set -a args --model $model
        _ai_agent_$runner $args
        return
    end

    set -l ep (_ai_agent_{$runner}_endpoint $provider $model)
    if test (count $ep) -lt 5; or test -z "$ep[1]"
        echo "$provider: no endpoint in the $runner config — add the provider there (baseUrl, apiKey, models)" >&2
        return 1
    end
    set -l url (string trim -r -c / -- $ep[1])/chat/completions
    set -l key (_ai_endpoint_key $ep[3])
    set -l ctx $ep[4]
    set -l max_tokens $ep[5]
    # Reasoning counts against max_tokens: a reasoner can spend ~10k tokens before the
    # answer, so the default must leave room for both
    test -n "$max_tokens"; or set max_tokens 16384
    set model (string replace -r -- '^'(string escape --style=regex -- $provider)'/' '' "$model")
    if test -z "$model"
        echo "$provider: no model given and none configured" >&2
        return 1
    end

    read -lz prompt
    # Deliberately low chars per token, so the estimate errs high (as for ollama)
    set -l prompt_tokens (math "round("(string length -- "$prompt")" / 3)")
    if test -n "$ctx"
        if test $prompt_tokens -ge $ctx
            echo "$provider: prompt ~$prompt_tokens tokens does not fit $model's $ctx-token context. Use --context-lines 0 (diff-only) or a smaller change." >&2
            return 1
        end
        if test (math $prompt_tokens + $max_tokens) -gt $ctx
            set max_tokens (math "max(1024, $ctx - $prompt_tokens)")
        end
        echo "$provider: prompt ~$prompt_tokens tokens, max_tokens $max_tokens, context $ctx (model $model)" >&2
    else
        echo "$provider: prompt ~$prompt_tokens tokens, max_tokens $max_tokens, context unknown — no contextWindow for $model in the $runner config" >&2
    end
    set -q _flag_no_think; and echo "$provider: --no-think is not supported for cloud models (the gateway rejects chat_template_kwargs) — ignoring" >&2

    set -l body (mktemp)
    set -l hdr (mktemp)
    set -l raw (mktemp)
    chmod 600 $hdr
    # The prompt through a file: a big review would overflow the argument limit
    printf '%s' "$prompt" >$raw
    jq -n --arg m $model --rawfile p $raw --argjson mt $max_tokens \
        '{model: $m, messages: [{role: "user", content: $p}], stream: true, stream_options: {include_usage: true}, max_tokens: $mt}' >$body
    # The key goes through a file, never the command line (ps would show it)
    printf 'Content-Type: application/json\n' >$hdr
    test -n "$key"; and printf 'Authorization: Bearer %s\n' $key >>$hdr

    # One jq for the whole stream: the answer to stdout as it arrives, leading blank
    # lines dropped. The raw stream is kept for the reasoning, usage and errors afterwards.
    curl -sS -N --connect-timeout 10 -H @$hdr -d @$body -w '\n__HTTP__%{http_code}\n' $url 2>$raw.err \
        | tee $raw \
        | jq -R -n -j --unbuffered 'foreach (inputs | select(startswith("data: {")) | .[6:] | fromjson? | .choices[0]?.delta?.content // empty) as $c
            ({s: false, out: ""};
             if .s then .out = $c
             else ($c | sub("^[[:space:]]+"; "")) as $t | if $t == "" then .out = "" else {s: true, out: $t} end end;
             .out)'
    set -l stream_rc $pipestatus
    set -l curl_rc $stream_rc[1]
    rm -f $body $hdr

    set -l rc 0
    set -l http (string match -r -g '^__HTTP__(\d+)$' <$raw)
    if test $curl_rc -ne 0
        switch $curl_rc
            case 6
                echo "$provider: cannot resolve the host in the $runner config — off the VPN?" >&2
            case 7
                echo "$provider: connection refused ($ep[1])" >&2
            case 28
                echo "$provider: timed out" >&2
            case '*'
                echo "$provider: curl failed (exit $curl_rc): "(head -1 $raw.err) >&2
        end
        set rc 1
    else if test "$http" != 200
        # Not a stream: a JSON error from the gateway, or an HTML page from a proxy
        set -l body_text (string match -v -r '^__HTTP__' <$raw | string collect)
        set -l msg (printf '%s' "$body_text" | jq -r '.error.message // empty' 2>/dev/null | head -1)
        test -n "$msg"; or set msg (string match -r -g '<title>(.*)</title>' -- $body_text | head -1)
        test -n "$msg"; or set msg (printf '%s\n' $body_text | head -1)
        echo "$provider: HTTP $http — $msg" >&2
        set rc 1
    else
        set -l chunks (mktemp)
        string match -r -g '^data: (\{.*)$' <$raw >$chunks
        set -l err (jq -r '.error.message? // empty' $chunks 2>/dev/null | head -1)
        if test -n "$err"
            echo "$provider: $err" >&2
            set rc 1
        else if test $stream_rc[3] -ne 0
            echo "$provider: could not parse the response stream" >&2
            set rc 1
        end
        if test -n "$_flag_thinking_output"
            jq -j '.choices[0]?.delta? | (.reasoning_content // .reasoning // empty)' $chunks >$_flag_thinking_output 2>/dev/null
        end
        set -l usage (jq -c 'select(.usage) | .usage' $chunks 2>/dev/null | tail -1)
        test -n "$_flag_usage_output"; and test -n "$usage"; and echo $usage >$_flag_usage_output
        if test "$(jq -r '.choices[0]?.finish_reason // empty' $chunks 2>/dev/null | tail -1)" = length
            echo "$provider: the answer hit max_tokens ($max_tokens) and is cut off — raise maxTokens for $model in the $runner config" >&2
        end
        rm -f $chunks
    end
    rm -f $raw $raw.err
    return $rc
end
