function _k_kubeconfig --description "Resolve the KUBECONFIG path for the k helpers"
    # Override per-shell/per-project by setting K_KUBECONFIG.
    if set -q K_KUBECONFIG
        echo $K_KUBECONFIG
    else
        echo /Users/alnovis/work/rf/local-config/k3s/config
    end
end
