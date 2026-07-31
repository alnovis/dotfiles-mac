function _k_complete_ns --description "List namespace names for k helper completions"
    set -lx KUBECONFIG (_k_kubeconfig)
    kubectl get ns -o 'custom-columns=NAME:.metadata.name' --no-headers 2>/dev/null
end
