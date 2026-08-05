# Completions for the `k` kubectl toolkit dispatcher.
#
# `k` is a closed set of helpers (pods/log/sh/desc/ns/pf), each with its own
# flags, plus `k x …` which delegates to raw kubectl (full native completion via
# `kubectl __complete`). No implicit passthrough — so completion is entirely ours
# and never spills kubectl noise into a helper context.

# Erase any prior `k` completions first — fish accumulates them, and a stale
# `complete -c k -w kubectl` from an earlier version would otherwise keep
# leaking kubectl verbs (e.g. `logs`) into our closed set. Makes re-sourcing
# idempotent without needing a fresh shell.
complete -c k -e

# First non-option token after `k` (the subcommand), or nothing.
function __k_subcommand
    set -l tokens (commandline -poc)
    for t in $tokens[2..-1]
        string match -q -- '-*' $t; and continue
        echo $t
        return 0
    end
    return 1
end

# True when the subcommand is one of the given helpers.
function __k_using
    contains -- (__k_subcommand) $argv
end

# Bridge `k x <args>` to kubectl's own completion engine. kubectl's __complete
# prints "value<tab>description" lines then a final ":<directive>" line; we strip
# the directive and hand the rest to fish.
function __k_x_complete
    set -lx KUBECONFIG (_k_kubeconfig)
    set -l tokens (commandline -poc)
    set -l rest
    set -l after 0
    for t in $tokens[2..-1]
        if test $after -eq 1
            set -a rest $t
        else if test "$t" = x
            set after 1
        end
    end
    set -l cur (commandline -ct)
    for line in (KUBECTL_ACTIVE_HELP=0 command kubectl __complete $rest "$cur" 2>/dev/null)
        string match -q -- ':*' $line; and continue
        test -n "$line"; and echo $line
    end
end

# --- first token: the closed command set ---
complete -c k -f
complete -c k -n __fish_use_subcommand -a pods -d "Pod overview (problems highlighted)"
complete -c k -n __fish_use_subcommand -a log  -d "Tail pod logs by name substring"
complete -c k -n __fish_use_subcommand -a sh   -d "Exec shell/command in a pod"
complete -c k -n __fish_use_subcommand -a desc -d "Describe pod + recent events"
complete -c k -n __fish_use_subcommand -a ns   -d "Show/switch default namespace"
complete -c k -n __fish_use_subcommand -a pf   -d "Port-forward to a pod"
complete -c k -n __fish_use_subcommand -a x    -d "Raw kubectl (KUBECONFIG baked in)"
complete -c k -n __fish_use_subcommand -a help -d "Show help"

# --- k pods [NS] ---
complete -c k -n "__k_using pods" -a '(_k_complete_ns)' -d Namespace
complete -c k -n "__k_using pods" -s n -l namespace -x -a '(_k_complete_ns)' -d Namespace

# --- pod-substring arg for log / sh / desc / pf ---
complete -c k -n "__k_using log sh desc pf" -a '(_k_complete_pods)' -d Pod
complete -c k -n "__k_using log sh desc pf" -s n -l namespace -x -a '(_k_complete_ns)' -d Namespace

# --- k log flags ---
complete -c k -n "__k_using log" -s f -l follow -d "Stream new log lines"
complete -c k -n "__k_using log" -s g -l grep -x -d "Filter output by pattern"
complete -c k -n "__k_using log" -s t -l tail -x -d "Number of tail lines"
complete -c k -n "__k_using log" -s p -l previous -d "Previous container instance"
complete -c k -n "__k_using log" -s c -l container -x -d "Container name"

# --- k sh flags ---
complete -c k -n "__k_using sh" -s c -l container -x -d "Container name"

# --- k ns [NAME] ---
complete -c k -n "__k_using ns" -a '(_k_complete_ns)' -d Namespace

# --- k x … → native kubectl completion ---
complete -c k -n "__k_using x" -f -a '(__k_x_complete)'

# After a file-taking flag in `k x`, re-enable path completion (apply -f, etc.).
function __k_x_wants_file
    __k_using x; or return 1
    set -l tokens (commandline -poc)
    contains -- $tokens[-1] -f --filename -k --kustomize
end
complete -c k -n __k_x_wants_file -F
