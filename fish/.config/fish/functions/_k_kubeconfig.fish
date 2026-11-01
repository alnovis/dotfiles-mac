function _k_kubeconfig --description "Resolve the KUBECONFIG path for the k helpers from \$K_KUBECONFIG"
    # Usage: _k_kubeconfig [--quiet]
    # The path is machine-specific, so it lives in a variable, never in the repo:
    #   set -Ux K_KUBECONFIG /path/to/kubeconfig
    # Unset or pointing at no file → error (silent with --quiet, for completions).
    argparse 'quiet' -- $argv; or return 1

    if not set -q K_KUBECONFIG; or test -z "$K_KUBECONFIG"
        set -q _flag_quiet; or echo "k: K_KUBECONFIG is not set — set it once with: set -Ux K_KUBECONFIG /path/to/kubeconfig" >&2
        return 1
    end
    if not test -f "$K_KUBECONFIG"
        set -q _flag_quiet; or echo "k: K_KUBECONFIG points to a missing file: $K_KUBECONFIG" >&2
        return 1
    end
    echo $K_KUBECONFIG
end
