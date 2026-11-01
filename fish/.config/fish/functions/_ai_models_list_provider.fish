function _ai_models_list_provider --description "Models of PROVIDER as a table (ollama: the local table; claude: its aliases; all: one table per provider)" --argument-names provider
    # One table per provider, grouped by label inside — the same two levels as the local
    # table. Columns differ because the data does: a cloud model has a context and a price,
    # not a size on disk.
    switch "$provider"
        case ollama
            _ai_models_list
            return
        case all
            _ai_models_list
            set -l runner (_ai_default_agent); or return 1
            for p in (_ai_agent_{$runner}_models | string split -f1 \t | sort -u | string match -v ollama)
                echo
                _ai_models_table_remote $p
            end
            echo
            _ai_models_table_remote claude
            return
    end
    _ai_models_table_remote $provider
end

function _ai_models_table_remote --description "One table: the models of a runner provider or claude, grouped by label" --argument-names provider
    set -l runner (_ai_default_agent); or return 1
    set -l models
    set -l title
    if test $provider = claude
        set models (_ai_agent_claude_models | string split -f2 \t)
        set title "claude (claude CLI)"
    else
        set -l rows (_ai_agent_{$runner}_models)
        set models (printf '%s\n' $rows | string match -r -g (printf '^%s\t(.+)$' (string escape --style=regex -- $provider)))
        if test (count $models) -eq 0
            set_color red
            echo "Runner $runner knows no provider '$provider' (providers: "(printf '%s\n' $rows | string split -f1 \t | sort -u | string join ", ")", claude)" >&2
            set_color normal
            return 1
        end
        set title (_ai_select_executor $provider none)[2]
    end

    # What the default and the tasks point at on this provider. A claude task with no model
    # runs on the CLI's own default — shown as its own row, since nothing here names it.
    set -l uses
    set -l cli_default "(CLI default)"
    if test (_ai_default_provider) = $provider
        set -l m (_ai_default_model "" $provider)
        test -z "$m"; and test $provider = claude; and set m $cli_default
        test -n "$m"; and set -a uses "$m|default"
    end
    for t in (_ai_tasks)
        test (_ai_default_provider $t) = $provider; or continue
        set -l m (_ai_config_read "$t"_model)
        test -z "$m"; and test $provider = claude; and set m $cli_default
        test -n "$m"; and set -a uses "$m|$t"
    end
    if string match -q -- "$cli_default|*" $uses
        set -a models $cli_default
    end

    # The gateway's own list too: a model it serves but the runner's config lacks still works
    # for a single call (the endpoint is per provider), but under --agentic / ai code the
    # runner gives it a tiny default context — the pi column shows which is which
    set -l prices
    set -l registered $models
    if test $provider != claude
        set prices (_ai_provider_prices $provider)
        # Over the list itself: printf with an empty list would still print one empty line
        for p in $prices
            set -l m (string split -f1 \t -- $p)
            contains -- $m $models; or set -a models $m
        end
    end

    set -l rows
    for m in $models
        set -l label (_ai_models_meta_get "@$provider/$m" label)
        test -n "$label"; or set label general
        set -l ctx
        set -l caps
        if test $provider != claude
            set -l ep (_ai_agent_{$runner}_endpoint $provider $m)
            set ctx $ep[4]
            test "$ep[6]" = true; and set caps thinking
        end
        # Type from the name only: "35b-a3b" is the usual total-active notation, so MoE for
        # sure; without it nothing can tell, and a blank is better than a guess
        set -l type
        set -l active (string match -r -i -g '\d+(?:\.\d+)?b-a(\d+(?:\.\d+)?)b' -- $m)
        test -n "$active"; and set type "MoE A"$active"B"
        set -l price
        set -l pf (printf '%s\n' $prices | string match -r -g (printf '^%s\t(.*)$' (string escape --style=regex -- $m)) | string split \t)
        test -n "$pf[1]$pf[2]"; and set price "$pf[1] / $pf[2]"
        set -l reg
        contains -- $m $registered; and set reg ✓
        set -l used (for u in $uses; set -l p (string split '|' -- $u); test "$p[1]" = $m; and echo $p[2]; end | string join ', ')
        set -a rows (string join \t -- $label $m "$ctx" "$type" "$caps" "$price" "$used" "$reg")
    end

    set_color --bold
    echo " $title"
    set_color normal
    set -l groups (for r in $rows; string split -f1 \t -- $r; end | sort -u | string match -v general)
    contains -- general (for r in $rows; string split -f1 \t -- $r; end); and set -a groups general
    # Laid out like the local table: a one-space first column where that one has its ">"
    set -l right 3
    test $provider = claude; and set right 0
    begin
        if test $provider = claude
            printf '%s\t%s\t%s\n' ' ' Model "Used for"
        else
            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' ' ' Model Context Type Capabilities $runner "Price in/out per 1M" "Used for"
        end
        for g in $groups
            echo "$(set_color cyan)"(string sub -l 1 -- $g | string upper)(string sub -s 2 -- $g)":$(set_color normal)"
            for r in (printf '%s\n' $rows | string match -- (printf '%s\t*' $g) | sort -t \t -k2)
                set -l f (string split \t -- $r)
                set -l used ''
                test -n "$f[7]"; and set used "$(set_color yellow)$f[7]$(set_color normal)"
                if test $provider = claude
                    printf '%s\t%s\t%s\n' ' ' $f[2] $used
                else
                    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' ' ' $f[2] $f[3] $f[4] $f[5] $f[8] $f[6] $used
                end
            end
        end
    end | table --header --rule --right $right --indent 1
end
