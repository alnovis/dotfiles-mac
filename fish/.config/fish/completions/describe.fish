# Completions for `describe`

complete -c describe -f

complete -c describe -s h -l help -d 'Show help'
complete -c describe -s d -l description -d 'Print only the description'
complete -c describe -s p -l path -d 'Print only the source file path'
complete -c describe -s b -l body -d 'Print only the highlighted body'
complete -c describe -l plain -d 'Disable syntax highlighting'

# Suggest the user's custom (autoloaded) functions, with their descriptions.
complete -c describe -n 'not __fish_seen_argument -h help' \
    -a '(functions --names | string match -rv "^_" )' \
    -d function
