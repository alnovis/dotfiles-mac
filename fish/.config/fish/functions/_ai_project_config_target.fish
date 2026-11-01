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
    # The reader (_ai_project_config_file) stops at $HOME and / without reading, so a
    # project config written there would never take effect — refuse instead
    if test "$root" = "$HOME"; or test "$root" = /
        echo "Error: no project here ($root) — run inside a project, or drop --project to use the global config" >&2
        return 1
    end
    echo $root/.ai/config
end
