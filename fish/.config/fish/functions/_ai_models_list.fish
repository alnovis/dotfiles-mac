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
        set -l caps (_ai_model_caps $tags[1] $digest | string split ' ')
        set -l capstr (for c in tools thinking vision; contains -- $c $caps; and echo $c; end | string join ,)
        set -l used (for u in $uses; set -l p (string split '|' -- $u); contains -- $p[1] $tags; and echo $p[2]; end | string join ', ')
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

        set -a rows (string join \t -- $label $name (math -s1 "$size / 1073741824")" GB" "$capstr" "$used" "$trialstr")
    end

    if test $n_models -eq 0
        test -n "$filter"; and echo "No installed model matches '$filter'"; or echo "No installed models"
        return 0
    end

    # Name column: as wide as the longest name, within limits
    set -l name_col 20
    for r in $rows
        set -l w (string length -- (string split \t -- $r)[2])
        test $w -gt $name_col; and set name_col $w
    end
    test $name_col -gt 46; and set name_col 46

    # Colours as in the pre-redesign list: cyan header, separators and group titles; a
    # yellow ">" on the default model; "Used for" in yellow; a model on trial in magenta.
    # Columns are printed one by one so the colour codes never count towards the padding.
    set -l sep (string repeat -n (math $name_col + 52) -- -)
    set_color cyan
    printf "   %-"$name_col"s %8s  %-21s %s\n" Model Size Capabilities "Used for"
    set_color normal
    echo " $sep"
    set -l groups (for r in $rows; string split -f1 \t -- $r; end | sort -u | string match -v general)
    contains -- general (for r in $rows; string split -f1 \t -- $r; end); and set -a groups general
    for g in $groups
        set_color cyan
        echo " "(string sub -l 1 -- $g | string upper)(string sub -s 2 -- $g)":"
        set_color normal
        for r in (printf '%s\n' $rows | string match -- (printf '%s\t*' $g) | sort -t \t -k2)
            set -l f (string split \t -- $r)
            set -l name $f[2]
            if test (string length -- $name) -gt $name_col
                set name (string sub -l (math $name_col - 1) -- $name)"~"
            end
            if contains -- default (string split ', ' -- $f[5])
                set_color yellow
                printf " > "
                set_color normal
            else
                printf "   "
            end
            printf "%-"$name_col"s %8s  %-21s " $name $f[3] $f[4]
            set_color yellow
            printf "%-16s" $f[5]
            set_color normal
            if test -n "$f[6]"
                set_color magenta
                printf " %s" $f[6]
                set_color normal
            end
            echo
        end
    end
    echo " $sep"

    echo
    set -l models_word models
    test $n_models -eq 1; and set models_word model
    set -l tags_word tags
    test $n_tags -eq 1; and set tags_word tag
    echo " $n_models $models_word ($n_tags $tags_word), "(math -s1 "$total_bytes / 1073741824")" GB on disk"
    echo " Details: ai models info NAME · try one: ai models try NAME:TAG · find: ai models search QUERY"
    echo " Per-task models: ai config status"
end
