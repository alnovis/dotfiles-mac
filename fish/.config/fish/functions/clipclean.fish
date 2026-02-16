function clipclean --description "Trim leading/trailing whitespace from clipboard"
    pbpaste | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | pbcopy
    echo "Clipboard cleaned"
end
