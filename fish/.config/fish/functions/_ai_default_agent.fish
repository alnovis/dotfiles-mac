function _ai_default_agent --description "Resolve the agent-runner: project/global config > default (pi)"
    # Symmetric with _ai_default_provider. Which runner backs --agentic for a
    # non-agentic provider. Only pi ships today; opencode/cline can drop in as
    # _ai_agent_<name> and be selected here.
    set -l a (_ai_config_read agent)
    if test $status -eq 0; and test -n "$a"
        echo $a
    else
        # Native ollama tool-loop is the default agentic backend: dynamic per-request
        # num_ctx, reads the repo, clean output, live progress. pi stays for `ai code`.
        echo ollama
    end
end
