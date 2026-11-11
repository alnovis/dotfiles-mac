function _ai_k --description "A count as the Run: footer writes it (_ai_run_stats): 950, 3.1k, 57.3k, 348k, 1.2M"
    # The same rule as the footer's jq `k`: one decimal below 100k, so a count that grows by
    # ~50 characters a second visibly moves (whole thousands stood still for 20 s and read as
    # a stuck line); whole thousands above, where a tenth is noise. A whole value has no ".0".
    if test $argv[1] -ge 1000000
        echo (math "round($argv[1] / 100000) / 10")M
    else if test $argv[1] -ge 100000
        echo (math "round($argv[1] / 1000)")k
    else if test $argv[1] -ge 1000
        echo (math "round($argv[1] / 100) / 10")k
    else
        echo $argv[1]
    end
end
