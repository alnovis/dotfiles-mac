function _ai_providers --description "List supported AI providers (discovered as _ai_provider_<name> functions)"
    for fn in (functions -an)
        if string match -rq '^_ai_provider_(?<name>.+)$' -- $fn
            functions -q $fn; and echo $name
        end
    end | sort
end
