function _ai_session_target --description "Where to write session NAME. Returns existing path if found; else project (git-root/.ai/sessions/) or global." --argument-names name scope
    set -l existing (_ai_session_file $name)
    if test -n "$existing"
        echo $existing
        return
    end

    if test "$scope" = global
        echo ~/.config/ai/sessions/$name.jsonl
        return
    end

    # Auto: project if in git repo, else global
    set -l root (git rev-parse --show-toplevel 2>/dev/null)
    if test -n "$root"
        echo $root/.ai/sessions/$name.jsonl
    else
        echo ~/.config/ai/sessions/$name.jsonl
    end
end
