function _ai_failure_reason --description "Why a run failed, one line, from its log on stdin: the last error-looking line, else the last line"
    # The log is the run's stderr: the runner's own messages and our run line,
    # "[run K/N  ]FAILED  12s  <why>" (_ai_run_watched). That line is skipped as an error of
    # its own — its <why> is the reason only when the log has no error line besides it.
    # Prints nothing for an empty log: the caller words its own fallback.
    # read, not (string trim): a command substitution does not get the function's stdin
    set -l raw
    while read -l line
        set -a raw $line
    end
    set -q raw[1]; or return 0
    # No ANSI codes (a coloured "FAILED" escaped the run-line pattern, and the reason became
    # the hint below it), an HTML error page as "503 Service Temporarily Unavailable"
    set -l lines
    for line in (printf '%s\n' $raw | _ai_runner_errors)
        set line (string trim -- $line)
        test -n "$line"; and set -a lines $line
    end
    set -q lines[1]; or return 0
    set -l own (string match -r -- '(?:^| )FAILED +[0-9]+s +(.*)$' $lines)[2]
    set -l rest (string match -v -r -- '(?:^| )FAILED +[0-9]+s ' $lines)
    set -l why
    if set -q rest[1]
        set why (string match -r -i -- '.*(?:http|error|forbidden|denied|refused|timed out|truncated|not found|\b[45][0-9][0-9]\b).*' $rest)[-1]
    end
    test -n "$why"; or set why $own
    test -n "$why"; or set why $rest[-1]
    test -n "$why"; and string shorten -m 200 -- $why
    return 0
end
