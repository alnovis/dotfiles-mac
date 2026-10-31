function _ai_default_agent --description "Resolve the runner for non-claude providers: project/global config key agent > pi"
    set -l a (_ai_config_read agent)
    test -n "$a"; or set a pi
    if not contains -- $a (_ai_agents)
        echo "Unknown runner '$a' in config key agent (valid: "(string join ", " (_ai_agents))")" >&2
        return 1
    end
    echo $a
end
