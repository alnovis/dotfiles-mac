function _k_ns --description "k ns: show or switch the default namespace"
    argparse 'h/help' -- $argv; or return 1

    if set -q _flag_help
        echo "Usage: k ns [NAMESPACE]"
        echo ""
        echo "With no argument, list namespaces and mark the current default."
        echo "With NAMESPACE, set it as the default for the current context."
        echo ""
        echo "Options:"
        echo "  -h, --help   Show this help"
        return 0
    end

    set -l current (kubectl config view --minify -o 'jsonpath={..namespace}' 2>/dev/null)
    test -z "$current"; and set current default

    set -l target $argv[1]

    if test -z "$target"
        echo "Namespaces (current: $current)"
        for n in (kubectl get ns -o 'custom-columns=NAME:.metadata.name' --no-headers 2>/dev/null)
            if test "$n" = "$current"
                set_color green
                echo "* $n"
                set_color normal
            else
                echo "  $n"
            end
        end
        return 0
    end

    if not kubectl get ns $target >/dev/null 2>&1
        echo "Namespace not found: $target" >&2
        return 1
    end

    kubectl config set-context --current --namespace=$target >/dev/null
    set_color green
    echo "Default namespace → $target"
    set_color normal
end
