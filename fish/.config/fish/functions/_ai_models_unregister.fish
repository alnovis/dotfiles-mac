function _ai_models_unregister --description "Remove deleted ollama models from the runners' configs (pi models.json, opencode config): they stay listed there otherwise"
    # Usage: _ai_models_unregister [--yes] TAG...
    # Called by ai models rm / drop once the model is gone: a runner would still offer it,
    # and a call to it would fail. A tag is matched as written and without :latest (the
    # configs list "x" for "x:latest"). Asks first, --yes does not; each file changed keeps
    # its previous version as <file>.bak.
    argparse y/yes -- $argv; or return 1
    set -l names (for t in $argv; echo $t; string replace -r ':latest$' '' -- $t; end | sort -u)
    set -q names[1]; or return 0
    set -l names_json (printf '%s\n' $names | jq -R . | jq -sc .)

    # runner<tab>file<tab>jq filter that drops them
    set -l hits
    set -l pi ~/.pi/agent/models.json
    if test -f $pi
        set -l n (jq --argjson n $names_json '[.providers.ollama.models[]? | select(.id | IN($n[]))] | length' $pi 2>/dev/null)
        test "$n" -gt 0 2>/dev/null
        and set -a hits pi\t$pi\t'.providers.ollama.models |= map(select(.id | IN($n[]) | not))'
    end
    for oc in ~/.config/opencode/opencode.json ~/.config/opencode/config.json
        test -f $oc; or continue
        set -l n (jq --argjson n $names_json '[(.provider.ollama.models // {}) | keys[] | select(IN($n[]))] | length' $oc 2>/dev/null)
        test "$n" -gt 0 2>/dev/null
        and set -a hits opencode\t$oc\t'.provider.ollama.models |= with_entries(select(.key | IN($n[]) | not))'
    end
    set -q hits[1]; or return 0

    echo "Still listed in the runners' configs:"
    for h in $hits
        set -l f (string split \t -- $h)
        echo "  $f[1]: $f[2]"
    end
    if not set -q _flag_yes
        read -l -P "Remove it from there too? [y/N] " confirm
        if test "$confirm" != y -a "$confirm" != Y
            echo "Kept there; a runner may still offer it"
            return 0
        end
    end
    for h in $hits
        set -l f (string split \t -- $h)
        cp $f[2] $f[2].bak; or continue
        if jq --argjson n $names_json $f[3] $f[2].bak >$f[2]
            echo "  removed from $f[1] (previous version: $f[2].bak)"
        else
            cp $f[2].bak $f[2]
            echo "  $f[1]: could not edit $f[2], left as it was" >&2
        end
    end
end
