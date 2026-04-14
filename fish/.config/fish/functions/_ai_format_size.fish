function _ai_format_size --description "Format bytes as human-readable GB" --argument-names bytes
    if test -z "$bytes"; or test "$bytes" = "0"; or test "$bytes" = null
        printf "  ?    "
        return
    end
    set -l gb (math -s1 "$bytes / 1073741824")
    printf "%6s" "$gb GB"
end
