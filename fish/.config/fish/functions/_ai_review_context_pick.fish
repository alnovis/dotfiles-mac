function _ai_review_context_pick --description "Pick the changed files to embed within BUDGET lines, callers first: rows 'lines<TAB>path' on stdin -> 'take|out<TAB>lines<TAB>path'" --argument-names tip budget
    # Over the budget the choice was all or nothing: on a 2.9k-line review, the 53k-token
    # diff alone or 121k with every file. The cloud qwen3.8 found the main bug with the
    # files and missed it with the diff alone: the scheduler that makes a digest per scan
    # was in a file the diff barely touched. So the files go in by how much they tell
    # about the new code, while they fit:
    #   1. code before tests;
    #   2. a file naming more of the other changed files first (their callers);
    #   3. a smaller one first (more files fit).
    # A file that does not fit is left out and the next one tried. Every row comes back,
    # taken ones first in that order.
    # read -z, not (cat): a command substitution does not get the function's piped stdin
    read -lz rows
    set rows (string split -n \n -- $rows)
    set -q rows[1]; or return 0
    set -l paths
    for row in $rows
        set -a paths (string split \t -- $row)[2]
    end
    # A changed file's name without its extension: what code that uses it writes
    set -l stems
    for p in $paths
        set -a stems (path change-extension '' -- (path basename -- $p))
    end
    set -l ranked
    for row in $rows
        set -l parts (string split \t -- $row)
        set -l name (path basename -- $parts[2])
        set -l test_file 0
        string match -qr '(^|/)(tests?|spec|__tests__)/' -- $parts[2]; and set test_file 1
        string match -qr '(Tests?|_test|\.test|\.spec|Spec)\.[^.]+$|^test_' -- $name; and set test_file 1
        # How many of the other changed files it names (short names say nothing: "Util")
        set -l own (path change-extension '' -- $name)
        set -l content (git show "$tip:$parts[2]" 2>/dev/null | string collect)
        set -l names 0
        for s in $stems
            test "$s" = "$own"; and continue
            test (string length -- $s) -ge 5; or continue
            string match -q -- "*$s*" $content; and set names (math $names + 1)
        end
        set -a ranked (printf '%s\t%s\t%s\t%s' $test_file $names $parts[1] $parts[2])
    end
    set -l used 0
    set -l taken
    set -l out
    for row in (printf '%s\n' $ranked | sort -t \t -k1,1n -k2,2nr -k3,3n -k4,4)
        set -l parts (string split \t -- $row)
        if test (math $used + $parts[3]) -le $budget
            set used (math $used + $parts[3])
            set -a taken (printf 'take\t%s\t%s' $parts[3] $parts[4])
        else
            set -a out (printf 'out\t%s\t%s' $parts[3] $parts[4])
        end
    end
    set -q taken[1]; and printf '%s\n' $taken
    set -q out[1]; and printf '%s\n' $out
    return 0
end
