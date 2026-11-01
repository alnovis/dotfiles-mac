function _ai_models_list --description "Installed ollama models (no network): one row per model, grouped by label; --provider P: a runner provider's models"
    # docs/refactoring.md §7a. Tags sharing a digest are one model (one row, one size).
    # Per-task resolution lives in `ai config status`; discovery on ollama.com (`ai models search`).
    argparse 'provider=' -- $argv; or return 1
    if set -q _flag_provider
        _ai_models_list_provider $_flag_provider
        return
    end
    set -l filter (string lower -- "$argv[1]")

    _ai_fetch_local
    set -l fetch $status
    set -l cache ~/.cache/ai-models.json
    if test $fetch -eq 2
        echo "No installed models known (ollama not reachable, no cache)." >&2
        return 1
    end
    if test $fetch -eq 1
        set_color yellow
        echo "[ollama not reachable — showing the cached list]"
        set_color normal
        echo
    end

    # What the default and the tasks point at (explicit task models only), canonical names
    set -l uses
    set -l dm (_ai_default_model "" ollama)
    test -n "$dm"; and set -a uses (_ai_model_norm $dm)"|default"
    for t in (_ai_tasks)
        test (_ai_default_provider $t) = ollama; or continue
        set -l m (_ai_config_read "$t"_model)
        test -n "$m"; and set -a uses (_ai_model_norm $m)"|$t"
    end

    # Which models the runner has registered for provider ollama: an unregistered one gets
    # the runner's tiny default context under --agentic / ai code / ai chat (empty answers)
    set -l runner (_ai_default_agent 2>/dev/null)
    set -l in_runner
    test -n "$runner"; and set in_runner (_ai_agent_{$runner}_models 2>/dev/null | string match -r -g '^ollama\t(.+)$')

    set -l rows
    set -l n_models 0
    set -l n_tags 0
    set -l total_bytes 0
    for r in (jq -r '.models | group_by(.digest)[] | [.[0].digest, (.[0].size | tostring), (map(.name) | join(","))] | @tsv' $cache)
        set -l f (string split \t -- $r)
        set -l digest $f[1]
        set -l size $f[2]
        set -l tags (string split , -- $f[3])
        if test -n "$filter"; and not string match -q -- "*$filter*" (string lower -- $tags)
            continue
        end
        set n_models (math $n_models + 1)
        set n_tags (math $n_tags + (count $tags))
        set total_bytes (math $total_bytes + $size)

        set -l label (_ai_models_meta_get $digest label)
        test -n "$label"; or set label general
        set -l arch (_ai_model_arch $tags[1] $digest)
        set -l caps (_ai_model_caps $tags[1] $digest | string split ' ')
        set -l capstr (for c in tools thinking vision; contains -- $c $caps; and echo $c; end | string join ,)
        set -l used (for u in $uses; set -l p (string split '|' -- $u); contains -- $p[1] $tags; and echo $p[2]; end | string join ', ')
        set -l reg
        for t in $tags
            if contains -- $t $in_runner; or contains -- (string replace -r ':latest$' '' -- $t) $in_runner
                set reg ✓
                break
            end
        end
        set -l trial (_ai_models_meta_get $digest trial)
        set -l trialstr
        test -n "$trial"; and set trialstr "trial, "(_ai_relative_time $trial | string replace ' ago' '')

        # Display name: the first tag, then the other tags of the same model
        set -l name $tags[1]
        set -l base (string split -m1 : -- $tags[1])[1]
        for x in $tags[2..]
            if string match -q -- "$base:*" $x
                set name "$name, :"(string split -m1 : -- $x)[2]
            else
                set name "$name, $x"
            end
        end

        set -a rows (string join \t -- $label $name (math -s1 "$size / 1073741824")" GB" "$arch" "$capstr" "$reg" "$used" "$trialstr")
    end

    if test $n_models -eq 0
        test -n "$filter"; and echo "No installed model matches '$filter'"; or echo "No installed models"
        return 0
    end

    # Colours as in the pre-redesign list: cyan header and group titles; a yellow ">" on
    # the default model; "Used for" in yellow; a model on trial in magenta. table measures
    # widths without the colour codes and caps the name column.
    set -l groups (for r in $rows; string split -f1 \t -- $r; end | sort -u | string match -v general)
    contains -- general (for r in $rows; string split -f1 \t -- $r; end); and set -a groups general
    # One table per provider (ai models --provider all): this one is titled like the others
    set_color --bold
    echo " ollama (local, native driver)"
    set_color normal
    begin
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' '' Model Size Type Capabilities "$runner" "Used for"
        # Colours as "$(set_color …)" inside quotes: without a colour terminal set_color
        # prints nothing, and a bare (set_color …) would be an empty list that makes the
        # whole concatenated word vanish
        for g in $groups
            echo "$(set_color cyan)"(string sub -l 1 -- $g | string upper)(string sub -s 2 -- $g)":$(set_color normal)"
            for r in (printf '%s\n' $rows | string match -- (printf '%s\t*' $g) | sort -t \t -k2)
                set -l f (string split \t -- $r)
                set -l mark ''
                contains -- default (string split ', ' -- $f[7]); and set mark "$(set_color yellow)>$(set_color normal)"
                set -l used ''
                test -n "$f[7]"; and set used "$(set_color yellow)$f[7]$(set_color normal)"
                set -l trial ''
                test -n "$f[8]"; and set trial "$(set_color magenta)$f[8]$(set_color normal)"
                printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' $mark $f[2] $f[3] $f[4] $f[5] $f[6] $used $trial
            end
        end
    end | table --header --rule --right 3 --max 2:46 --indent 1

    echo
    set -l models_word models
    test $n_models -eq 1; and set models_word model
    set -l tags_word tags
    test $n_tags -eq 1; and set tags_word tag
    echo " $n_models $models_word ($n_tags $tags_word), "(math -s1 "$total_bytes / 1073741824")" GB on disk"
    echo " Details: ai models info NAME · try one: ai models try NAME:TAG · find: ai models search QUERY"
    echo " Per-task models: ai config status"
end
