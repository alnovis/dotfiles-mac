function _ai_agents --description "List available agent-runners (discovered as _ai_agent_<name> functions)"
    for fn in (functions -an)
        if string match -rq '^_ai_agent_(?<name>.+)$' -- $fn
            functions -q $fn; and echo $name
        end
    end | sort
end
