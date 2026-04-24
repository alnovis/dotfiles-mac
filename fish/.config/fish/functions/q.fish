function q --description "Quick alias manager: lightweight named commands"
    set -l quick_dir ~/.config/quick

    if not test -d $quick_dir
        mkdir -p $quick_dir
    end

    set -l subcmd $argv[1]

    switch "$subcmd"
        case add
            # q add name "command" [-d description]
            # q add name [-d description]  → opens $EDITOR for multiline
            set -l rest $argv[2..]
            argparse 'h/help' 'd/description=' -- $rest
            or return 1

            if set -q _flag_help
                echo "Usage: q add <name> <command> [-d description]"
                echo "       q add <name> [-d description]   # opens \$EDITOR"
                return 0
            end

            set -l name $argv[1]
            if test -z "$name"
                echo "Usage: q add <name> <command> [-d description]"
                return 1
            end

            set -l desc "$_flag_description"
            if test -z "$desc"
                set desc "$name"
            end

            set -l cmd $argv[2]

            if test -z "$cmd"
                # No command given — open editor
                set -l tmpfile (mktemp /tmp/q-edit-XXXXXX)
                printf '%s\n' "$desc" >$tmpfile

                # Pre-fill with existing command if updating
                if test -f $quick_dir/$name
                    tail -n +2 $quick_dir/$name >>$tmpfile
                end

                eval $EDITOR $tmpfile

                # Check if user wrote anything beyond the description line
                if test (wc -l <$tmpfile | string trim) -le 1
                    rm $tmpfile
                    echo "Aborted: no command entered."
                    return 1
                end

                cp $tmpfile $quick_dir/$name
                rm $tmpfile

                set_color green
                echo "Added: $name"
                set_color normal
                tail -n +2 $quick_dir/$name
            else
                # Inline single-line command
                printf '%s\n%s\n' "$desc" "$cmd" >$quick_dir/$name

                set_color green
                echo "Added: $name"
                set_color normal
                echo "  $cmd"
            end

        case rm remove
            if contains -- "$argv[2]" --help -h
                echo "Usage: q rm <name> [name...]"
                return 0
            end

            if test -z "$argv[2]"
                echo "Usage: q rm <name>"
                return 1
            end

            for name in $argv[2..]
                if test -f $quick_dir/$name
                    rm $quick_dir/$name
                    set_color yellow
                    echo "Removed: $name"
                    set_color normal
                else
                    set_color red
                    echo "Not found: $name"
                    set_color normal
                    return 1
                end
            end

        case ls list
            set -l files $quick_dir/*
            if test (count $files) -eq 0; or not test -e $files[1]
                echo "No quick commands saved."
                echo "Usage: q add <name> <command> [-d description]"
                return 0
            end

            for f in $files
                set -l name (basename $f)
                set -l desc (head -1 $f)
                set_color cyan
                printf '%-20s' $name
                set_color normal
                echo " $desc"
            end

        case show
            if contains -- "$argv[2]" --help -h
                echo "Usage: q show <name>"
                return 0
            end

            if test -z "$argv[2]"
                echo "Usage: q show <name>"
                return 1
            end

            set -l name $argv[2]
            if not test -f $quick_dir/$name
                set_color red
                echo "Not found: $name"
                set_color normal
                return 1
            end

            set -l desc (head -1 $quick_dir/$name)
            set -l cmd (tail -n +2 $quick_dir/$name)
            set_color cyan
            echo "# $desc"
            set_color normal
            echo "$cmd"

        case edit
            if contains -- "$argv[2]" --help -h
                echo "Usage: q edit <name>"
                return 0
            end

            if test -z "$argv[2]"
                echo "Usage: q edit <name>"
                return 1
            end

            set -l name $argv[2]
            if not test -f $quick_dir/$name
                set_color red
                echo "Not found: $name"
                set_color normal
                return 1
            end

            eval $EDITOR $quick_dir/$name

        case --help -h help ''
            echo "Usage: q <name> [args...]       Run a quick command"
            echo "       q add <name> <cmd> [-d]  Save a quick command (inline)"
            echo "       q add <name> [-d]        Save a quick command (\$EDITOR)"
            echo "       q ls                     List all quick commands"
            echo "       q show <name>            Show command without running"
            echo "       q edit <name>            Edit in \$EDITOR"
            echo "       q rm <name>              Remove a quick command"
            echo ""
            echo "Options:"
            echo "  -d, --description TEXT    Description (for add)"
            echo ""
            echo "Examples:"
            echo "  q add pg_dev \"PGPASSWORD=dev psql -h db.local -U dev\" -d \"dev database\""
            echo "  q add deploy -d \"full deploy\"  # opens editor for multiline"
            echo "  q pg_dev                       # runs the saved command"
            echo "  q ls                           # list all"
            echo ""
            echo "Quick commands are stored in ~/.config/quick/"
            return 0

        case '*'
            # Default: run the command by name
            set -l name $argv[1]
            if not test -f $quick_dir/$name
                set_color red
                echo "Unknown command: $name"
                set_color normal
                echo "Run 'q ls' to see available commands or 'q add' to create one."
                return 1
            end

            set -l cmd (tail -n +2 $quick_dir/$name | string collect)
            # Pass extra args to the command
            if test (count $argv) -gt 1
                eval $cmd $argv[2..]
            else
                eval $cmd
            end
    end
end
