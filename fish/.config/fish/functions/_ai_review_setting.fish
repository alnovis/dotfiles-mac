function _ai_review_setting --description "Config KEY for PROVIDER and MODEL: prints value<TAB>origin; scoped keys KEY@PROVIDER/MODEL and KEY@PROVIDER win over KEY" --argument-names key provider model
    # Project config first, then global; inside one file the narrowest scope wins:
    #   review_runs@litellm/selectel/qwen/qwen3.8-27b=3   one model
    #   review_runs@litellm=3                              every model of a provider
    #   review_runs=1                                      everyone
    # Nothing set: prints nothing and fails, the caller applies its built-in default.
    set -l names
    test -n "$provider"; and test -n "$model"; and set -a names "$key@$provider/$model"
    test -n "$provider"; and set -a names "$key@$provider"
    set -a names $key
    set -l files
    set -l proj (_ai_project_config_file)
    test -n "$proj"; and set -a files $proj
    set -a files ~/.config/ai/config
    for f in $files
        for n in $names
            set -l v (_ai_config_read_file $f $n)
            if test $status -eq 0; and test -n "$v"
                set -l layer global
                test "$f" = "$proj"; and set layer project
                printf '%s\t%s\n' $v "$layer $n"
                return 0
            end
        end
    end
    return 1
end
