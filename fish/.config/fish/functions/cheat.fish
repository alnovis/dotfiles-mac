function cheat --description "Cheat sheet for a command via cheat.sh"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: cheat <command> [topic]"
        echo ""
        echo "Show cheat sheet for a command via cheat.sh."
        echo ""
        echo "Examples:"
        echo "  cheat tar"
        echo "  cheat git rebase"
        echo "  cheat jq"
        return 0
    end

    if test (count $argv) -eq 0
        echo "Usage: cheat <command> [topic]"
        return 1
    end

    set -l query (string join "/" $argv)
    curl -s "cheat.sh/$query" | bat --style=plain --paging=always
end
