function _ai_providers_ls --description "List providers with the executor serving them (no network)"
    set -l fmt "%-12s %-26s %s\n"
    printf $fmt PROVIDER EXECUTOR MODELS

    set -l n_local (jq '[.models[]?] | length' ~/.cache/ai-models.json 2>/dev/null; or echo 0)
    printf $fmt ollama "native ($(_ai_ollama_host | string replace -r '^https?://' ''))" "$n_local installed (single-shot)"

    set -l claude_state "claude CLI"
    command -q claude; or set claude_state "claude CLI (not installed!)"
    printf $fmt claude $claude_state "sonnet, opus, haiku"

    set -l runner (_ai_default_agent); or return 1
    set -l rows (_ai_agent_{$runner}_models)
    for p in (printf '%s\n' $rows | string split -f1 \t | sort -u)
        set -l n (printf '%s\n' $rows | string match -- (printf '%s\t*' $p) | count)
        set -l note
        test "$p" = ollama; and set note " (--agentic, ai code)"
        printf $fmt $p "via $runner" "$n$note"
    end

    echo
    echo " Reachable now? ai providers check NAME · runner: config key agent ($runner)"
end
