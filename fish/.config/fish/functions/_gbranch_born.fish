function _gbranch_born --description "Earliest reflog time (unix) of a branch, local or origin; empty if unknown"
    set -l name $argv[1]
    set -l times
    for ref in refs/heads/$name refs/remotes/origin/$name
        set -a times (git reflog show --date=unix --format=%gd $ref 2>/dev/null | tail -1 | string match -rg '@\{(\d+)\}$')
    end
    test (count $times) -gt 0; or return 1
    printf '%s\n' $times | sort -n | head -1
end
