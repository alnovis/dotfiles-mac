function set-ci-token --description "Set CI_PERSONAL_TOKEN or CI_REGISTRY"
    argparse 'r/registry' -- $argv; or return 1

    if set -q _flag_registry
        if test (count $argv) -eq 1
            set -U CI_REGISTRY $argv[1]
        else
            read -l -P "CI_REGISTRY: " value
            if test -z "$value"
                echo "Aborted"
                return 1
            end
            set -U CI_REGISTRY $value
        end
        echo "CI_REGISTRY updated"
    else
        if test (count $argv) -eq 1
            set -U CI_PERSONAL_TOKEN $argv[1]
        else
            read -l -P "CI_PERSONAL_TOKEN: " value
            if test -z "$value"
                echo "Aborted"
                return 1
            end
            set -U CI_PERSONAL_TOKEN $value
        end
        echo "CI_PERSONAL_TOKEN updated"
    end
end
