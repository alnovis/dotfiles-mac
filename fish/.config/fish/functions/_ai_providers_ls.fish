function _ai_providers_ls --description "List providers with the executors serving them (no network)"
    # Two executor columns, because one provider is served differently by mode: a single
    # call (review, gen, top-level ai) vs tools or chat history (--agentic, ai code, ai chat).
    set -l runner (_ai_default_agent); or return 1
    set -l rows (_ai_agent_{$runner}_models)

    # Models, not tags: tags sharing a digest are one model (as in ai models)
    set -l n_local (jq '[.models[]?.digest] | unique | length' ~/.cache/ai-models.json 2>/dev/null; or echo 0)
    set -l n_reg (printf '%s\n' $rows | string match -- (printf 'ollama\t*') | count)
    set -l claude_state "claude CLI"
    command -q claude; or set claude_state "claude CLI (not installed!)"

    begin
        printf '%s\t%s\t%s\t%s\n' Provider "Single call" "Tools / chat" Models
        printf '%s\t%s\t%s\t%s\n' ollama "native ($(_ai_ollama_host | string replace -r '^https?://' ''))" "via $runner" "$n_local installed, $n_reg in $runner"
        printf '%s\t%s\t%s\t%s\n' claude $claude_state $claude_state "sonnet, opus, haiku"
        for p in (printf '%s\n' $rows | string split -f1 \t | sort -u | string match -v ollama)
            set -l n (printf '%s\n' $rows | string match -- (printf '%s\t*' $p) | count)
            set -l single (_ai_select_executor $p none 2>/dev/null)[2]
            # "litellm (native, endpoint from pi)" → "native, endpoint from pi"
            set single (string replace -r '^\S+ \((.*)\)$' '$1' -- "$single")
            printf '%s\t%s\t%s\t%s\n' $p "$single" "via $runner" $n
        end
    end | table --header --rule --indent 1

    echo
    echo " Reachable now? ai providers check NAME · runner: config key agent ($runner) · models: ai models --provider all"
end
