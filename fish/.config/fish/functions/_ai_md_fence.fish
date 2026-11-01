function _ai_md_fence --description "A markdown code fence longer than any backtick run in CONTENT (at least three)"
    # Args: CONTENT
    # A file that itself contains ``` (a markdown file, a prompt template) would close a
    # three-backtick fence early and spill the rest of the file out of the code block.
    set -l n 3
    for run in (string match -ar '`{3,}' -- $argv[1])
        set -l len (string length -- $run)
        test $len -ge $n; and set n (math $len + 1)
    end
    string repeat -n $n '`'
end
