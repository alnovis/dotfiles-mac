function _ai_agent_claude_models --description "Models of the claude runner, as provider<TAB>model lines"
    # The claude CLI has no model listing; these are its stable aliases.
    printf 'claude\t%s\n' sonnet opus haiku
end
