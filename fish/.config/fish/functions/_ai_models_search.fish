function _ai_models_search --description "Search ollama.com in the browser (ollama has no search API)"
    # Discovery stays on the site; `ai models info NAME:TAG` then reads a found model's
    # details from the registry before downloading anything.
    set -l url https://ollama.com/search
    test (count $argv) -gt 0; and set url "$url?q="(string escape --style=url -- (string join ' ' $argv))
    echo $url
    open $url
end
