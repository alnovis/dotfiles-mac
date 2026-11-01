function _ai_review_prompt_mode --description "Review prompt depth for PROVIDER (AGENTIC 1|0): full or lean; --origin prints why"
    # The full prompt adds the ABSENCE gate and the sibling sweep (from VVAH, tuned for
    # Claude). A small local model turns each of those rules into another round of
    # second-guessing: on a real work change qwen3.6 thought 2.2× longer and dropped the finding the
    # lean prompt caught. So the depth follows the executor, never a list of "strong"
    # models: the native ollama driver (a local model) gets lean; claude, the runners
    # (cloud providers) and --agentic get full. Config key review_prompt overrides.
    argparse origin -- $argv; or return 1
    set -l provider $argv[1]
    set -l agentic $argv[2]

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
    else if test "$provider" = ollama; and test "$agentic" != 1
        set mode lean
        set origin "auto: local model on the native ollama driver"
    else
        set mode full
        set origin "auto: claude, a runner or --agentic"
    end

    if set -q _flag_origin
        echo "$mode ($origin)"
    else
        echo $mode
    end
end
