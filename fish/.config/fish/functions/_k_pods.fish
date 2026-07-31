function _k_pods --description "k pods: overview of pods across namespaces; problems highlighted"
    argparse 'h/help' 'n/namespace=' -- $argv; or return 1

    if set -q _flag_help
        echo "Usage: k pods [OPTIONS] [NAMESPACE]"
        echo ""
        echo "Overview of pods; non-Running / not-ready pods are highlighted."
        echo "Defaults to all namespaces."
        echo ""
        echo "Options:"
        echo "  -n, --namespace=NS   Limit to a namespace (same as positional NAMESPACE)"
        echo "  -h, --help           Show this help"
        echo ""
        echo "Examples:"
        echo "  k pods            All pods, all namespaces"
        echo "  k pods kafka      Only the kafka namespace"
        return 0
    end

    set -l ns $_flag_namespace
    if test -z "$ns"
        set ns $argv[1]
    end

    set -l sel -A
    if test -n "$ns"
        set sel -n $ns
    end

    # Single query so header and rows share kubectl's column widths.
    set -l out (kubectl get pods $sel -o wide 2>/dev/null)
    if test (count $out) -lt 1
        echo "No pods found"
        return 0
    end
    set -l header $out[1]
    set -l rows
    if test (count $out) -ge 2
        set rows $out[2..-1]
    end

    if test -n "$ns"
        echo "Pods: namespace $ns"
    else
        echo "Pods: all namespaces"
    end

    set_color cyan
    echo $header
    set_color normal

    set -l ok 0
    set -l problem 0
    for row in $rows
        if not string match -rq 'Running|Completed|Succeeded' -- $row
            set_color red
            echo $row
            set_color normal
            set problem (math $problem + 1)
        else if string match -rq ' 0/[0-9]' -- $row
            set_color yellow
            echo $row
            set_color normal
            set problem (math $problem + 1)
        else
            echo $row
            set ok (math $ok + 1)
        end
    end

    set -l total (count $rows)
    echo "---"
    set -l summary "$total pods"
    set -a summary (set_color green)"$ok healthy"(set_color normal)
    if test $problem -gt 0
        set -a summary (set_color red)"$problem need attention"(set_color normal)
    end
    echo (string join ", " $summary)
end
