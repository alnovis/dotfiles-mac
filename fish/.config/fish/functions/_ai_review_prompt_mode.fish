function _ai_review_prompt_mode --description "Review prompt depth for PROVIDER: full or lean; --origin prints why"
    # The full prompt adds the ABSENCE gate and the sibling sweep (from VVAH, tuned for
    # Claude). Other models turn each of those rules into another round of second-guessing.
    # On a real work change qwen3.6 did worse with them both locally (2.2x the thinking,
    # the race dropped) and in the cloud (the race over-graded, two false Important) — so
    # it is the model, not where it runs: full goes to claude only. Config key
    # review_prompt overrides.
    argparse origin -- $argv; or return 1
    set -l provider $argv[1]

    set -l v (_ai_config_read review_prompt)
    if test -n "$v"; and not contains -- $v auto full lean
        set_color yellow >&2
        echo "Warning: review_prompt=$v is not auto, full or lean — using auto" >&2
        set_color normal >&2
        set v auto
    end

    set -l mode
    set -l origin
    if contains -- "$v" full lean
        set mode $v
        set origin "config review_prompt=$v"
    else if test "$provider" = claude
        set mode full
        set origin "auto: claude"
    else
        set mode lean
        set origin "auto: not claude"
    end

    if set -q _flag_origin
        echo "$mode ($origin)"
    else
        echo $mode
    end
end
