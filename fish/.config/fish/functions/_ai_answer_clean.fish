function _ai_answer_clean --description "Clean a runner's answer FILE in place: drop a model's leaked control tokens; status 3 when the answer is a tool call written as text"
    # Seen on the local-model eval through pi's /v1 (ollama's parser for the model failed):
    # - north-mini's turn markers in the text: drafts and reasoning glued before the answer,
    #   "…<|END_THINKING|><|START_TEXT|>## Summary …" three times over (653 lines, 179
    #   "findings"). The answer is what follows the last <|START_TEXT|>; other <|…|> go.
    # - a tool call the runner did not parse, left as the "answer": north-mini's
    #   "<|START_ACTION|>[{"tool_name": "find", …}]<|END_ACTION|>", or qwen2.5-coder's bare
    #   '{"name": "read", "arguments": {…}}'. No answer at all: the caller reports it as one.
    # Plain answers are left as they are, byte for byte.
    set -l file $argv[1]
    test -s "$file"; or return 0
    set -l text (cat $file | string collect)
    if string match -q -r -- '<\|[A-Z_]+\|>' $text
        # A tool call that ends the text is not an answer, whatever came before it
        if string match -q -r -- '<\|START_ACTION\|>(?:(?!<\|START_TEXT\|>).)*$' (string join ' ' -- (string split \n -- $text))
            return 3
        end
        string match -q -- '*<|START_TEXT|>*' $text
        and set text (string split -- '<|START_TEXT|>' $text)[-1]
        set text (string replace -ra -- '<\|[A-Z_]+\|>' '' $text | string collect)
        printf '%s\n' (string trim -- $text) >$file
    end
    # Nothing but JSON tool calls ({"name": …, "arguments": …}), one or more
    set -l flat (string join ' ' -- (string split \n -- (cat $file | string collect)))
    if string match -q -r -- '^\s*(?:\{\s*"name"\s*:\s*"[A-Za-z_][\w.-]*"\s*,\s*"arguments"\s*:\s*\{[^{}]*\}\s*\}\s*)+$' $flat
        return 3
    end
    return 0
end
