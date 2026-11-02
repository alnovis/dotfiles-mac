function _ai_runs_failed_lines --description "Summary lines for the runs that failed (\$__ai_runs_failed entries), in yellow"
    # Called inside the green "… saved to" summary: leaves the colour green again
    set -q argv[1]; or return 0
    set_color yellow
    echo "Failed:            $argv[1]"
    for f in $argv[2..]
        echo "                   $f"
    end
    set_color green
end
