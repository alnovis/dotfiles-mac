function _ai_agents --description "List the runners selectable with the agent config key"
    # Explicit list, not discovery by function name: _ai_agent_<runner>_models / _probe
    # helpers share the prefix. claude is a runner too, but it is tied to --provider claude
    # rather than selected here.
    printf '%s\n' pi opencode
end
