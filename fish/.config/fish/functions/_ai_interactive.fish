function _ai_interactive --description "Start an interactive session for TASK with PROFILE through the selected executor"
    # Usage: _ai_interactive --task T --profile none|read|edit [--provider P] [--model M]
    #                        [--runner] [--continue] [--resume] [--dry-run] [-- ARGS for the executor]
    # Same executor choice as _ai_run (docs/refactoring.md §5): claude → the claude CLI;
    # ollama with no tools → `ollama run`; anything else → the runner (agent key).
    # --runner: never `ollama run` (no history there) — ollama goes through the runner too.
    argparse 'task=' 'profile=' 'provider=' 'model=' 'runner' 'continue' 'resume' 'dry-run' -- $argv; or return 1

    set -l provider $_flag_provider
    test -n "$provider"; or set provider (_ai_default_provider $_flag_task)
    set -l model $_flag_model
    test -n "$model"; or set model (_ai_default_model $_flag_task $provider)

    set -l need
    set -q _flag_runner; and set need runner
    set -l sel (_ai_select_executor $provider $_flag_profile $need); or return 1
    set -l dispatch $sel[1]
    set model (_ai_executor_model $dispatch $provider "$model"); or return 1

    if set -q _flag_dry_run
        set -l m $model
        test -n "$m"; or set m "(executor default)"
        set -l how interactive
        set -q _flag_continue; and set how "$how, continue last"
        set -q _flag_resume; and set how "$how, resume (pick)"
        echo "would start: $sel[2], $how, model $m"
        test (count $argv) -gt 0; and echo "  passing: $argv"
        return 0
    end

    if test "$dispatch" = _ai_provider_ollama
        _ai_provider_ollama --interactive --model $model
        return
    end

    set -l args --interactive --provider $provider --tools $_flag_profile
    test -n "$model"; and set -a args --model $model
    set -q _flag_continue; and set -a args --continue
    set -q _flag_resume; and set -a args --resume
    $dispatch $args $argv
end
