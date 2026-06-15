function _ai_sessions_pin --description "Pin provider/model for session NAME; subsequent runs use these regardless of task defaults"
    argparse 'provider=' 'model=' -- $argv; or return 1

    set -l name $argv[1]
    if test -z "$name"
        set_color red
        echo "Error: name required — ai sessions pin NAME [--provider P] [--model M]"
        set_color normal
        return 1
    end

    set -l file (_ai_session_file $name)
    if test -z "$file"
        set_color red
        echo "Error: session '$name' not found"
        set_color normal
        return 1
    end

    set -l provider $_flag_provider
    set -l model $_flag_model

    if test -z "$provider"; and test -z "$model"
        set_color red
        echo "Error: specify --provider and/or --model to pin"
        set_color normal
        return 1
    end

    set -l now (date -u +"%Y-%m-%dT%H:%M:%SZ")
    jq -nc --arg p "$provider" --arg m "$model" --arg ts "$now" \
        '{t:"config", pinned:true, provider:(if $p == "" then null else $p end), model:(if $m == "" then null else $m end), ts:$ts}' >>$file

    set_color green
    echo "Pinned: $name → provider=$provider model=$model"
    set_color normal
end
