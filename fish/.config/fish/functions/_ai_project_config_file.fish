function _ai_project_config_file --description "Walk up from PWD to find nearest .ai/config; empty if none. Stops at git-root / \$HOME / /."
    set -l dir $PWD

    while true
        # Stop conditions checked before reading so $HOME/.ai/config is not picked up as 'project'
        if test "$dir" = "$HOME"; or test "$dir" = /
            return 1
        end

        if test -f "$dir/.ai/config"
            echo "$dir/.ai/config"
            return 0
        end

        # git-root is the project boundary — check this dir's .ai/config first (done above),
        # then refuse to search beyond it.
        if test -d "$dir/.git"
            return 1
        end

        set dir (dirname $dir)
    end
end
