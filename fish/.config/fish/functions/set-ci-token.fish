function set-ci-token --description "Set CI_PERSONAL_TOKEN or CI_REGISTRY"
    argparse 'h/help' 'r/registry' -- $argv; or return 1

    if set -q _flag_help
        echo "Usage: set-ci-token [OPTIONS] [VALUE]"
        echo ""
        echo "Set or update CI_PERSONAL_TOKEN or CI_REGISTRY."
        echo "Values are stored as Fish universal variables."
        echo ""
        echo "Options:"
        echo "  -r, --registry   Set CI_REGISTRY instead of token"
        echo "  -h, --help       Show this help"
        echo ""
        echo "Examples:"
        echo "  set-ci-token                  Interactive token input"
        echo "  set-ci-token TOKEN            Set token directly"
        echo "  set-ci-token -r               Interactive registry input"
        echo "  set-ci-token -r host:port     Set registry directly"
        return 0
    end

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
