# Completions for `table` (reads TSV from stdin, so no file arguments)

complete -c table -f

complete -c table -s h -l help -d 'Show help'
complete -c table -l header -d 'First line is the header (cyan, rule under it)'
complete -c table -l rule -d 'Close the table with a rule'
complete -c table -l right -x -d 'Right-align columns (1-based, comma-separated)'
complete -c table -l max -x -d 'Cap a column: COL:N, cut with ~ (repeatable)'
complete -c table -l gap -x -d 'Spaces between columns (default 2)'
complete -c table -l indent -x -d 'Spaces before every line'
complete -c table -s s -l sep -x -d 'Column separator (default: tab)'
