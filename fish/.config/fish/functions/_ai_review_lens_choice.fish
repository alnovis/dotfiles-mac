function _ai_review_lens_choice --description "Lenses for a review: --lens > --no-lens > review_lens (project config, then global) > none; prints lenses<TAB>origin" --argument-names flag_value no_lens
    # Lenses follow the code, not the model: review_lens is read from the project's .ai/config
    # (walk-up) before the global config, unscoped. Prints nothing (and fails) when no lens
    # applies. Prints no errors either: it runs inside (…), whose stderr would skip the caller's
    # redirect — the caller rejects --lens with --no-lens, and an unknown name is reported
    # when the lens block is built.
    if test -n "$flag_value"
        printf '%s\t%s\n' $flag_value --lens
        return 0
    end
    test -n "$no_lens"; and return 1
    set -l s (_ai_review_setting review_lens "" "" | string split \t); or return 1
    printf '%s\t%s\n' $s[1] "config: $s[2]"
end
