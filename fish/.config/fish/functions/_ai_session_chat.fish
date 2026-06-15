function _ai_session_chat --description "Run interactive REPL for session NAME (ollama only)"
    argparse 'global' 'system=' 'model=' -- $argv; or return 1

    set -l name $argv[1]
    if test -z "$name"
        set_color red
        echo "Error: session name required" >&2
        set_color normal
        return 1
    end

    set -l scope ""
    set -q _flag_global; and set scope global
    set -l file (_ai_session_target $name $scope)

    # Init new file with meta + optional system prompt
    if not test -f $file
        mkdir -p (dirname $file)
        set -l now (date -u +"%Y-%m-%dT%H:%M:%SZ")
        jq -nc --arg name "$name" --arg now "$now" '{t:"meta", name:$name, created:$now, updated:$now}' >$file
        if set -q _flag_system; and test -n "$_flag_system"
            jq -nc --arg c "$_flag_system" '{t:"system", content:$c}' >>$file
        end
    end

    # Resolve model: explicit flag → pin (latest config block with pinned:true) → task config → fallback
    set -l model $_flag_model
    set -l pin_active 0
    if test -z "$model"
        if test -f $file
            set -l pinned (jq -s 'last(.[] | select(.t == "config" and .pinned == true)) // empty' $file 2>/dev/null)
            if test -n "$pinned"; and test "$pinned" != null
                set -l pin_model (echo $pinned | jq -r '.model // empty')
                if test -n "$pin_model"; and test "$pin_model" != null
                    set model $pin_model
                    set pin_active 1
                end
            end
        end
        if test -z "$model"
            set model (_ai_default_model chat ollama)
        end
    end

    _ai_ensure_running; or return 1

    # Header
    set -l turns 0
    if test -f $file
        set turns (grep -c '"t":"assistant"' $file)
    end
    set_color cyan
    set -l pin_str ""
    test $pin_active -eq 1; and set pin_str " [pinned]"
    echo "[session: $name — $turns turns — ollama / $model$pin_str]"
    set_color normal
    echo "(Ctrl-D to exit)"
    echo

    # REPL
    while true
        set_color brblue
        printf '> '
        set_color normal

        if not read -l user_input
            echo
            break
        end
        if test -z "$user_input"
            continue
        end

        # Append user turn
        set -l now (date -u +"%Y-%m-%dT%H:%M:%SZ")
        jq -nc --arg c "$user_input" --arg ts "$now" '{t:"user", content:$c, ts:$ts}' >>$file

        # Maybe roll a summary of old turns if we're nearing context limit.
        # Side-effects: writes a {t:"summary"} row to the file. stderr → terminal.
        _ai_session_maybe_summarize $file $model

        # Build messages array (still applies sliding window if needed even after summary)
        set -l err_tmp (mktemp -t ai-chat-err.XXXXX)
        set -l messages (_ai_session_build_messages $file $model 2>$err_tmp)
        set -l trunc_hint (cat $err_tmp 2>/dev/null)
        rm -f $err_tmp

        if test -n "$trunc_hint"
            set_color brblack
            echo "[$trunc_hint]"
            set_color normal
        end

        # Stream the assistant turn
        set -l meta_tmp (mktemp -t ai-chat.XXXXX)
        echo
        _ai_provider_ollama_chat --model $model --messages $messages --meta-file $meta_tmp
        echo

        # Append assistant turn
        if test -f $meta_tmp; and test -s $meta_tmp
            set -l content (jq -r '.content' $meta_tmp)
            set -l usage (jq -c '.usage' $meta_tmp)
            set -l now2 (date -u +"%Y-%m-%dT%H:%M:%SZ")
            jq -nc --arg c "$content" --arg ts "$now2" --arg m "$model" --argjson u "$usage" \
                '{t:"assistant", content:$c, ts:$ts, model:$m, usage:$u}' >>$file
        end
        rm -f $meta_tmp
    end

    set_color brblack
    echo "(session saved → $file)"
    set_color normal
end
