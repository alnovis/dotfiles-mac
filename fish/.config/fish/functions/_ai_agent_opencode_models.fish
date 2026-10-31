function _ai_agent_opencode_models --description "Models opencode knows, as provider<TAB>model lines"
    command opencode models 2>/dev/null | string replace -r '^([^/]+)/' '$1\t'
end
