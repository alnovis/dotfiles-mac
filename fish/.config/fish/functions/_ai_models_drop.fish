function _ai_models_drop --description "Remove a model entirely (every tag of it) and its metadata — the end of a trial that didn't work out"
    argparse y/yes -- $argv; or return 1
    if test (count $argv) -lt 1
        set_color red
        echo "Error: specify model — ai models drop NAME"
        set_color normal
        return 1
    end
    set -l model (_ai_model_norm $argv[1])
    _ai_fetch_local >/dev/null
    set -l digest (_ai_model_digest $model)
    if test -z "$digest"
        echo "Error: $model is not installed" >&2
        return 1
    end

    # Removing one tag frees nothing while another tag points at the same blobs
    set -l tags (jq -r --arg d $digest '.models[] | select(.digest == $d) | .name' ~/.cache/ai-models.json)
    set -l users
    set -l dm (_ai_default_model "" ollama)
    test -n "$dm"; and contains -- (_ai_model_norm $dm) $tags; and set -a users default
    for t in (_ai_tasks)
        set -l m (_ai_config_read "$t"_model)
        test -n "$m"; and contains -- (_ai_model_norm $m) $tags; and set -a users $t
    end
    if test (count $users) -gt 0
        set_color yellow
        echo "Still configured for: "(string join ", " $users)" — those will fail until changed"
        set_color normal
    end

    if not set -q _flag_yes
        read -l -P "Remove "(string join ", " $tags)"? [y/N] " confirm
        if test "$confirm" != y -a "$confirm" != Y
            echo Aborted
            return 1
        end
    end

    _ai_ensure_running; or return 1
    for t in $tags
        ollama rm $t; or return 1
    end
    for field in label trial name
        _ai_models_meta_set $digest $field ''
    end
    _ai_fetch_local >/dev/null
    set_color green
    echo "Dropped: "(string join ", " $tags)
    set_color normal
end
