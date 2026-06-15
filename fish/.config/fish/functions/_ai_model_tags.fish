function _ai_model_tags --description "Tags showing which task(s) point at MODEL (for inline display in 'ai models list')" --argument-names model
    # Returns comma-separated tag list:
    # - "default" if MODEL == global ollama default
    # - <task> for each task whose explicit override resolves to MODEL on ollama provider
    # Skips tasks with non-ollama provider (those models aren't in the ollama-centric list).

    set -l tags

    set -l gp (_ai_default_provider)
    if test "$gp" = ollama
        set -l gm (_ai_default_model "" ollama)
        if test "$gm" = "$model"
            set -a tags default
        end
    end

    for t in (_ai_tasks)
        set -l p (_ai_default_provider $t)
        if test "$p" != ollama
            continue
        end
        set -l explicit (_ai_config_read "$t"_model)
        if test $status -ne 0; or test -z "$explicit"
            continue
        end
        if test "$explicit" = "$model"
            set -a tags $t
        end
    end

    if test (count $tags) -gt 0
        string join ", " $tags
    end
end
