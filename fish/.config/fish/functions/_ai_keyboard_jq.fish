function _ai_keyboard_jq --description "A jq def, keyboard: a string in characters typed on a keyboard, code in backticks left as it is"
    # Comments go to a merge request, and people asked for text they could have typed:
    # typographic dashes, arrows, guillemets, curly quotes, an ellipsis, bullets, middle dots
    # and non-breaking spaces become - -> " ' ... and a space. Letters of any language stay.
    # The odd parts between backticks are code (inline, or a ``` block): quoted from the
    # source, so left as they are. Printed for a caller to put before its own program:
    #   jq (_ai_keyboard_jq | string collect)'.body |= keyboard'
    # Escapes, not the characters: the file stays ASCII.
    printf '%s\n' 'def keyboard:
    [splits("`")] as $p
    | [range(0; $p | length) as $i
       | if $i % 2 == 1 then $p[$i] else $p[$i]
           | gsub("[\u2012\u2013\u2014\u2015\u2212]"; "-")
           | gsub("\u2192"; "->") | gsub("\u2190"; "<-") | gsub("\u21d2"; "=>") | gsub("\u2194"; "<->")
           | gsub("\u2026"; "...")
           | gsub("[\u00ab\u00bb\u201c\u201d\u201e\u2033]"; "\"")
           | gsub("[\u2018\u2019\u201a\u2032]"; "\u0027")
           | gsub("\u2264"; "<=") | gsub("\u2265"; ">=") | gsub("\u2260"; "!=") | gsub("\u00d7"; "x")
           | gsub("[\u2022\u00b7]"; "-")
           | gsub("[\u00a0\u2009\u202f]"; " ")
         end]
    | join("`");'
end
