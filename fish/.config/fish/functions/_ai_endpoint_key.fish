function _ai_endpoint_key --description "Resolve a runner's apiKey reference: \$VAR or {env:VAR} → that variable's value, anything else → as is" --argument-names ref
    # pi writes "$LITELLM_API_KEY", opencode "{env:LITELLM_API_KEY}"; a literal key stays a
    # literal. An unset variable resolves to nothing (the request then goes without a key).
    set -l name (string match -r -g '^\$([A-Za-z_][A-Za-z0-9_]*)$' -- $ref)
    test -n "$name"; or set name (string match -r -g '^\{env:([A-Za-z_][A-Za-z0-9_]*)\}$' -- $ref)
    if test -n "$name"
        set -q $name; and echo $$name
        return 0
    end
    echo $ref
end
