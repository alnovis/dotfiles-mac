function registry-login --description "Docker login to private registry"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: registry-login"
        echo ""
        echo "Docker login to private registry."
        echo "Uses CI_REGISTRY and CI_PERSONAL_TOKEN universal variables."
        echo "Set them with: set-ci-token, set-ci-token --registry <url>"
        return 0
    end

    if not set -q CI_REGISTRY; or test -z "$CI_REGISTRY"
        echo "CI_REGISTRY is not set. Run: set-ci-token --registry <url>"
        return 1
    end
    if not set -q CI_PERSONAL_TOKEN; or test -z "$CI_PERSONAL_TOKEN"
        echo "CI_PERSONAL_TOKEN is not set. Run: set-ci-token <token>"
        return 1
    end
    echo "$CI_PERSONAL_TOKEN" | docker login "$CI_REGISTRY" --username Private-Token --password-stdin $argv
end
