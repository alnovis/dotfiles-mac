function _ai_runner_errors --description "A runner's stderr made readable (stdin → stdout): no ANSI codes, an HTML error page as one line"
    # A gateway in front of the provider answers an outage with its own HTML page, and the
    # runner prints it whole: "503 <html>", then eight lines of markup per run. Kept: the
    # status and the page's <title> ("503 Service Temporarily Unavailable"). The colours of
    # a run line written without a terminal hid "FAILED" from the reason's pattern.
    # read, not (string …): a command substitution does not get the function's stdin
    set -l lines
    while read -l line
        set -a lines (string replace -ra '\e\[[0-9;?]*[A-Za-z]' '' -- $line)
    end
    set -q lines[1]; or return 0
    set -l title (string match -r -i -- '<title>\s*([^<]*?)\s*</title>' $lines)[2]
    set -l page 0
    for line in $lines
        if test -n "$title"
            # "503 <html>" opens the page: its status and title stand for the whole page
            set -l code (string match -r -- '^\s*([1-5][0-9][0-9])\s+<' $line)[2]
            if test -n "$code"
                string match -q -r -- "^$code" $title; and echo $title; or echo "$code $title"
                set page 1
                continue
            end
            # The markup itself: a line that is only tags and the text inside them
            if string match -q -r -- '^\s*<' $line
                test $page -eq 0; and echo $title
                set page 1
                continue
            end
        end
        echo $line
    end
end
