function _k_complete_pods --description "List 'pod\tnamespace' for k helper completions"
    set -lx KUBECONFIG (_k_kubeconfig)
    kubectl get pods -A -o 'custom-columns=NAME:.metadata.name,NS:.metadata.namespace' --no-headers 2>/dev/null \
        | string replace -r '\s+' \t
end
