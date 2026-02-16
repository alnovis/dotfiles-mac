function clipcommit --description "Git commit with trimmed clipboard as message"
    set msg (pbpaste | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | string collect)
    if test -z "$msg"
        echo "Clipboard is empty"
        return 1
    end
    echo "Commit message:"
    echo "$msg"
    echo "---"
    git commit -m "$msg"
end
