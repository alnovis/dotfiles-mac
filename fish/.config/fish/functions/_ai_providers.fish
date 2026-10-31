function _ai_providers --description "List providers: ollama (native), claude, and those the selected runner knows"
    # Runner providers come from the runner's own config (pi models.json, opencode config),
    # not from ours — see docs/refactoring.md §3.
    begin
        echo ollama
        echo claude
        set -l runner (_ai_default_agent 2>/dev/null)
        and _ai_agent_{$runner}_models | string split -f1 \t
    end | sort -u
end
