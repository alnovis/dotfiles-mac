function _ai_agent_pi_models --description "Models pi knows, as provider<TAB>model lines"
    # pi --list-models prints a table (provider, model, context, …) from its own config;
    # --offline skips its startup network checks.
    command pi --offline --list-models 2>/dev/null | awk 'NR > 1 && NF >= 2 { print $1 "\t" $2 }'
end
