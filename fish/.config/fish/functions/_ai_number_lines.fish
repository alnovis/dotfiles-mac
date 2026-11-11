function _ai_number_lines --description "Number stdin's lines as the prompts show code: '%5d  line' (stdin → stdout)"
    # Whole files went into the prompt bare while the prompt asks for file:line, and the
    # models counted the lines themselves in their reasoning: 215 lines of "103: (blank)" in
    # one qwen3.8 run on a 3842-line review, which then ran out of max_tokens with no answer.
    # The same format as the code _ai_verify_context assembles for verify.
    awk '{ printf "%5d  %s\n", NR, $0 }'
end
