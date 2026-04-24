# Completions for q (quick alias manager)

# Helper: list saved quick command names with descriptions
function __q_commands
    set -l quick_dir ~/.config/quick
    if test -d $quick_dir
        for f in $quick_dir/*
            if test -f $f
                set -l name (basename $f)
                set -l desc (head -1 $f)
                printf '%s\t%s\n' $name $desc
            end
        end
    end
end

# Condition: no subcommand yet
function __q_no_subcmd
    set -l subcmds add rm remove ls list show edit help
    set -l cmd (commandline -opc)
    for s in $subcmds
        if contains -- $s $cmd[2..]
            return 1
        end
    end
    # Check if first arg is a known quick command (then we're in "run" mode)
    if test (count $cmd) -ge 2
        set -l quick_dir ~/.config/quick
        if test -f $quick_dir/$cmd[2]
            return 1
        end
    end
    return 0
end

# Disable file completions by default
complete -c q -f

# Subcommands (only when no subcommand given yet)
complete -c q -n __q_no_subcmd -a add -d "Save a quick command"
complete -c q -n __q_no_subcmd -a ls -d "List all quick commands"
complete -c q -n __q_no_subcmd -a rm -d "Remove a quick command"
complete -c q -n __q_no_subcmd -a show -d "Show command details"
complete -c q -n __q_no_subcmd -a edit -d "Edit in \$EDITOR"
complete -c q -n __q_no_subcmd -a help -d "Show help"

# Quick command names as direct arguments (for running)
complete -c q -n __q_no_subcmd -a "(__q_commands)"

# Completions for rm/remove — suggest existing commands
complete -c q -n "__fish_seen_subcommand_from rm remove" -a "(__q_commands)"

# Completions for show — suggest existing commands
complete -c q -n "__fish_seen_subcommand_from show" -a "(__q_commands)"

# Completions for edit — suggest existing commands
complete -c q -n "__fish_seen_subcommand_from edit" -a "(__q_commands)"

# Completions for add — flags
complete -c q -n "__fish_seen_subcommand_from add" -s d -l description -d "Command description"
