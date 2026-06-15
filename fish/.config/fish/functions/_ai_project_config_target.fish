function _ai_project_config_target --description "Path to write project config: existing if found, else git-root/.ai/config or PWD/.ai/config"
    set -l existing (_ai_project_config_file)
    if test -n "$existing"
        echo $existing
        return
    end

    set -l root (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$root"
        set root $PWD
    end
    echo $root/.ai/config
end
