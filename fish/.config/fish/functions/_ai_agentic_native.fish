function _ai_provider_agentic_native --description "True if a provider is already tool-grounded (needs no agent-runner for --agentic)"
    # `claude -p` always has tools and reads the repo itself, so --agentic is satisfied
    # natively — no runner needed. A bare provider like ollama is NOT tool-grounded, so
    # --agentic routes it through an agent-runner (see _ai_default_agent). Extend this
    # list as providers gain native tool use.
    contains -- "$argv[1]" claude
end
