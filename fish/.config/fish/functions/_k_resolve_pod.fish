function _k_resolve_pod --description "Resolve a pod-name substring to 'namespace<tab>pod'"
    set -l substr $argv[1]
    set -l ns $argv[2]

    if test -z "$substr"
        echo "resolve: missing pod substring" >&2
        return 1
    end

    set -lx KUBECONFIG (_k_kubeconfig)

    set -l sel -A
    if test -n "$ns"
        set sel -n $ns
    end

    set -l rows (kubectl get pods $sel -o 'custom-columns=NS:.metadata.namespace,NAME:.metadata.name' --no-headers 2>/dev/null)
    if test -z "$rows"
        echo "resolve: no pods found" >&2
        return 1
    end

    set -l matches
    for row in $rows
        set -l fields (string split -n ' ' -- $row)
        if string match -q "*$substr*" -- $fields[2]
            set -a matches (string join \t $fields[1] $fields[2])
        end
    end

    set -l n (count $matches)
    if test $n -eq 0
        echo "resolve: no pod matching '$substr'" >&2
        return 1
    else if test $n -eq 1
        echo $matches[1]
        return 0
    else
        echo "resolve: '$substr' matches $n pods:" >&2
        for m in $matches
            set -l f (string split \t -- $m)
            echo "  $f[2]  ($f[1])" >&2
        end
        return 2
    end
end
