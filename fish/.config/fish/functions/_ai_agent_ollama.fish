function _ai_agent_ollama --description "AI agent-runner: native ollama tool-loop with DYNAMIC per-request num_ctx"
    # The proper answer to dynamic agentic context. Unlike pi (which uses the static
    # server-side OLLAMA_CONTEXT_LENGTH), this drives ollama's /api/chat tool-calling
    # loop ourselves, so we set options.num_ctx PER REQUEST — sized to the growing
    # message history, clamped to the model's native ceiling and a RAM cap. Same
    # dynamic-sizing philosophy as the non-agentic HTTP provider, now for agentic.
    #
    # Contract (mirrors _ai_agent_pi's non-interactive path):
    #   --model M         ollama model id (required)
    #   --workdir DIR     repo the read-only tools operate in (default: PWD)
    #   --think           allow the model's thinking (default OFF — keeps output clean,
    #                     which is exactly what fixes the "thinking leak" some models show)
    #   --max-iters N     tool-loop cap (default 24) — a runaway backstop
    #   --provider/--edit/--no-session/--interactive  accepted for interface symmetry, ignored
    # Reads the prompt from stdin, streams the final answer to stdout. Live turn/tool
    # progress goes to stderr (we own the loop, so it is free).
    argparse 'model=' 'workdir=' 'think' 'max-iters=' 'provider=' 'edit' 'no-session' 'interactive' -- $argv; or return 1

    set -l model $_flag_model
    if test -z "$model"
        echo "_ai_agent_ollama: --model is required" >&2
        return 1
    end
    set -l workdir $_flag_workdir
    test -z "$workdir"; and set workdir $PWD
    set -l max_iters 24
    test -n "$_flag_max_iters"; and set max_iters $_flag_max_iters
    set -l think false
    set -q _flag_think; and set think true

    if not command -q jq; or not command -q curl
        echo "_ai_agent_ollama: jq and curl are required" >&2
        return 1
    end
    _ai_ensure_running; or return 1

    set -l host http://localhost:11434
    if set -q OLLAMA_HOST; and test -n "$OLLAMA_HOST"
        string match -q 'http*' -- $OLLAMA_HOST; and set host $OLLAMA_HOST; or set host "http://$OLLAMA_HOST"
    end

    # Model native context ceiling (metadata read, no GPU load), clamped by a RAM cap.
    set -l model_max (ollama show $model 2>/dev/null | string match -rg 'context length\s+(\d+)')
    test -z "$model_max"; and set model_max 32768
    set -l ram_cap 131072
    set -q AI_OLLAMA_MAX_CTX; and test -n "$AI_OLLAMA_MAX_CTX"; and set ram_cap $AI_OLLAMA_MAX_CTX
    set -l ctx_ceiling (math "min($model_max, $ram_cap)")

    # Read-only tool set advertised to the model (JSON schema).
    set -l tools_json '[
      {"type":"function","function":{"name":"read_file","description":"Read a text file from the repo. Returns its contents.","parameters":{"type":"object","properties":{"path":{"type":"string","description":"path relative to the repo root"}},"required":["path"]}}},
      {"type":"function","function":{"name":"grep","description":"Search the repo for a regex. Returns matching file:line rows.","parameters":{"type":"object","properties":{"pattern":{"type":"string"},"path":{"type":"string","description":"optional file or dir to scope the search"}},"required":["pattern"]}}},
      {"type":"function","function":{"name":"find_files","description":"Find files whose path matches a glob/substring.","parameters":{"type":"object","properties":{"pattern":{"type":"string"}},"required":["pattern"]}}},
      {"type":"function","function":{"name":"list_dir","description":"List a directory.","parameters":{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}}}
    ]'

    # Message history lives in a temp JSON array; jq appends to it each turn.
    read -lz prompt
    set -l msgs (mktemp)
    jq -n --arg p "$prompt" '[
      {role:"system",content:"You are reviewing a repository through read-only tools (read_file, grep, find_files, list_dir). Tool paths are RELATIVE to the repo root — never absolute paths like /workspace. If you do not know the layout, call list_dir with path \".\" first, then read the files you need. When finished exploring, output your answer as plain text."},
      {role:"user",content:$p}
    ]' >$msgs

    set -l tty 0
    isatty stderr; and set tty 1
    set -l t0 (date +%s)

    set -l final ""
    set -l iter 0
    while test $iter -lt $max_iters
        set iter (math $iter + 1)

        # DYNAMIC num_ctx: size to the whole history + output reserve, clamp to ceiling.
        set -l chars (wc -c <$msgs | string trim)
        set -l tokens (math "round($chars / 3.5)")
        set -l num_ctx (math "min($ctx_ceiling, max(8192, ceil(($tokens + 8192) / 4096) * 4096))")

        if test $tty -eq 1
            printf '\r\033[K  ollama · %s | turn %d | thinking… | ctx %d | %ds' \
                $model $iter $num_ctx (math (date +%s) - $t0) >&2
        end

        # One /api/chat round, STREAMED — so the elapsed clock ticks DURING generation,
        # not just between turns (a single long turn was freezing the status line). fish
        # pipeline bodies run in a subshell (local vars are lost), so content and
        # tool-calls are accumulated to FILES and reassembled afterwards.
        set -l reqfile (mktemp)
        jq -c --argjson tools $tools_json --argjson ctx $num_ctx --argjson think $think --arg m $model \
            '{model:$m, messages:., tools:$tools, stream:true, think:$think, options:{num_ctx:$ctx}}' $msgs >$reqfile
        set -l accfile (mktemp)
        set -l metafile (mktemp)
        : >$accfile; : >$metafile
        curl -s --no-buffer $host/api/chat -d @$reqfile 2>/dev/null | while read -l chunk
            test -z "$chunk"; and continue
            printf '%s' $chunk | jq -j '.message.content // ""' >>$accfile 2>/dev/null
            printf '%s' $chunk | jq -c '{tc:(.message.tool_calls // null), err:(.error // null)}' >>$metafile 2>/dev/null
            test $tty -eq 1; and printf '\r\033[K  ollama · %s | turn %d | generating… | ctx %d | %ds' \
                $model $iter $num_ctx (math (date +%s) - $t0) >&2
        end
        rm -f $reqfile

        set -l err (jq -rc 'select(.err != null) | .err' $metafile 2>/dev/null | head -1)
        if test -n "$err"
            test $tty -eq 1; and printf '\r\033[K' >&2
            echo "_ai_agent_ollama: api error: $err" >&2
            rm -f $msgs $accfile $metafile
            return 1
        end
        set -l content (cat $accfile | string collect)
        set -l tcalls (jq -c 'select(.tc != null) | .tc' $metafile 2>/dev/null | tail -1)
        rm -f $accfile $metafile

        # Reassemble the assistant message and append it to the history.
        if test -n "$tcalls"
            jq -n --arg c "$content" --argjson tc $tcalls '{role:"assistant",content:$c,tool_calls:$tc}' >$msgs.asst
        else
            jq -n --arg c "$content" '{role:"assistant",content:$c}' >$msgs.asst
        end
        jq --slurpfile a $msgs.asst '. + $a' $msgs >$msgs.new; and mv $msgs.new $msgs
        rm -f $msgs.asst

        set -l ncalls 0
        test -n "$tcalls"; and set ncalls (echo $tcalls | jq 'length')
        if test "$ncalls" -gt 0
            # Execute each tool call read-only and append a tool result message.
            for i in (seq 1 $ncalls)
                set -l call (echo $tcalls | jq -c ".[$(math $i - 1)]")
                set -l name (echo $call | jq -r '.function.name')
                set -l args (echo $call | jq -c '.function.arguments')
                if test $tty -eq 1
                    set -l a1 (echo $args | jq -r '.path // .pattern // ""' | string sub -l 40)
                    printf '\r\033[K  ollama · %s | turn %d | %s %s | ctx %d | %ds' \
                        $model $iter $name "$a1" $num_ctx (math (date +%s) - $t0) >&2
                end
                set -l result (_ai_agent_ollama_tool $workdir $name $args | string collect)
                jq -n --arg n $name --arg c "$result" '{role:"tool",tool_name:$n,content:$c}' >$msgs.tool
                jq --slurpfile t $msgs.tool '. + $t' $msgs >$msgs.new; and mv $msgs.new $msgs
                rm -f $msgs.tool
            end
        else
            # Final answer. Some models (north-mini) leak thinking-channel markers into
            # content even with think:false — keep the answer after <|START_TEXT|>, then
            # strip residual markers. `string collect` MUST be the last command in each
            # substitution: otherwise fish splits the multi-line result into a list and
            # `printf "$final"` re-joins it with spaces, destroying all the newlines.
            set final $content
            string match -q '*<|START_TEXT|>*' -- $final
            and set final (string replace -r '(?s).*<\|START_TEXT\|>' '' -- $final | string collect)
            set final (string replace -ra '<\|[^|]*\|>' '' -- $final | string collect)
            break
        end
    end

    test $tty -eq 1; and printf '\r\033[K' >&2
    rm -f $msgs
    if test -z "$final"
        echo "_ai_agent_ollama: no final answer after $iter turns (hit --max-iters?)" >&2
        return 1
    end
    printf '%s' "$final"
end

function _ai_agent_ollama_tool --description "Execute one read-only tool for _ai_agent_ollama, in WORKDIR"
    # Usage: _ai_agent_ollama_tool WORKDIR NAME ARGS_JSON  → prints the tool result
    set -l workdir $argv[1]
    set -l name $argv[2]
    set -l args $argv[3]
    set -l prev $PWD
    cd $workdir 2>/dev/null; or begin; echo "cannot cd to workdir"; return; end
    switch $name
        case read_file
            set -l p (echo $args | jq -r '.path')
            if test -d "$p"
                echo "$p is a directory — use list_dir to see its contents"
            else if test -f "$p"
                head -c 20000 "$p"    # cap to keep the context bounded
            else
                echo "no such file: $p"
            end
        case grep
            set -l pat (echo $args | jq -r '.pattern')
            set -l p (echo $args | jq -r '.path // "."')
            grep -rnI --exclude-dir=.git -- "$pat" "$p" 2>/dev/null | head -c 8000; or echo "no matches"
        case find_files
            set -l pat (echo $args | jq -r '.pattern')
            if command -q fd
                fd --hidden --glob --exclude .git -- "$pat" 2>/dev/null | head -c 6000
            else
                find . -path ./.git -prune -o -iname "$pat" -print 2>/dev/null | head -c 6000
            end
        case list_dir
            set -l p (echo $args | jq -r '.path // "."')
            ls -la "$p" 2>/dev/null | head -c 6000; or echo "cannot list: $p"
        case '*'
            echo "unknown tool: $name"
    end
    cd $prev 2>/dev/null
end
