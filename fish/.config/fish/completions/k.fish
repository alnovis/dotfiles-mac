# Completions for the `k` kubectl toolkit dispatcher.
#
# Two layers:
#   1. Our smart helpers (pods/log/sh/desc/ns/pf) + their args.
#   2. Transparent kubectl passthrough for every other verb (get, apply, ...).

# Inherit kubectl's own completions for the passthrough path.
if type -q kubectl; and not functions -q __kubectl_debug
    kubectl completion fish 2>/dev/null | source
end
complete -c k -w kubectl

set -l k_subs pods log sh desc ns pf

# --- first token: our helpers (shown alongside kubectl's verbs) ---
complete -c k -n "not __fish_seen_subcommand_from $k_subs" -a pods -d "Pod overview (problems highlighted)"
complete -c k -n "not __fish_seen_subcommand_from $k_subs" -a log  -d "Tail pod logs by name substring"
complete -c k -n "not __fish_seen_subcommand_from $k_subs" -a sh   -d "Exec shell/command in a pod"
complete -c k -n "not __fish_seen_subcommand_from $k_subs" -a desc -d "Describe pod + recent events"
complete -c k -n "not __fish_seen_subcommand_from $k_subs" -a ns   -d "Show/switch default namespace"
complete -c k -n "not __fish_seen_subcommand_from $k_subs" -a pf   -d "Port-forward to a pod"

# --- k pods [NS] ---
complete -c k -n "__fish_seen_subcommand_from pods" -a '(_k_complete_ns)' -d Namespace
complete -c k -n "__fish_seen_subcommand_from pods" -s n -l namespace -x -a '(_k_complete_ns)' -d Namespace

# --- pod-substring arg for log / sh / desc / pf ---
complete -c k -n "__fish_seen_subcommand_from log sh desc pf" -a '(_k_complete_pods)' -d Pod
complete -c k -n "__fish_seen_subcommand_from log sh desc pf" -s n -l namespace -x -a '(_k_complete_ns)' -d Namespace

# --- k log flags ---
complete -c k -n "__fish_seen_subcommand_from log" -s f -l follow -d "Stream new log lines"
complete -c k -n "__fish_seen_subcommand_from log" -s g -l grep -x -d "Filter output by pattern"
complete -c k -n "__fish_seen_subcommand_from log" -s t -l tail -x -d "Number of tail lines"
complete -c k -n "__fish_seen_subcommand_from log" -s p -l previous -d "Previous container instance"
complete -c k -n "__fish_seen_subcommand_from log" -s c -l container -x -d "Container name"

# --- k sh flags ---
complete -c k -n "__fish_seen_subcommand_from sh" -s c -l container -x -d "Container name"

# --- k ns [NAME] ---
complete -c k -n "__fish_seen_subcommand_from ns" -a '(_k_complete_ns)' -d Namespace
