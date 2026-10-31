function _ai_complete_models --description "Complete model names for --model/--verify-model, for the provider on the command line"
    # The provider comes from --provider on the command line (--verify: --verify-provider
    # first). ollama or none: the installed-model cache (~/.cache/ai-models.json), which works
    # with the server DOWN — a raw `ollama list` returns nothing then; claude: its aliases;
    # any other provider: the models the runner lists for it. No provider + --verify also
    # offers the claude aliases, since the verify pass is commonly a cloud model.
    argparse verify -- $argv 2>/dev/null

    set -l toks (commandline -opc)
    set -l flags --provider
    set -q _flag_verify; and set flags --verify-provider --provider
    set -l provider
    for f in $flags
        set -l i (contains -i -- $f $toks)
        if test -n "$i"; and test (count $toks) -gt $i
            set provider $toks[(math $i + 1)]
        else
            set provider (string replace -rf -- "^$f=" '' $toks)[1]
        end
        test -n "$provider"; and break
    end

    switch "$provider"
        case '' ollama
            set -l names (_ai_get_installed_names)
            if test -z "$names[1]"
                # Cache cold — best-effort live query (may be empty if the server is down).
                set names (ollama list 2>/dev/null | tail -n +2 | awk '{print $1}')
            end
            printf '%s\n' $names
            if test -z "$provider"; and set -q _flag_verify
                _ai_agent_claude_models | string split -f2 \t | string replace -r '$' \t'Claude (cloud)'
            end
        case claude
            _ai_agent_claude_models | string split -f2 \t
        case '*'
            set -l runner (_ai_default_agent 2>/dev/null); or return
            _ai_agent_{$runner}_models | string match -r -g (printf '^%s\t(.+)$' (string escape --style=regex -- $provider))
    end
end
