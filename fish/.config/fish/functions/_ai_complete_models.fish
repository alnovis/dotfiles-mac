function _ai_complete_models --description "Complete model names for ai --model/--verify-model (server-free)"
    # Robust source: the installed-model cache (~/.cache/ai-models.json), which
    # works even when the ollama server is DOWN — unlike a raw `ollama list`, whose
    # /api/tags call returns nothing with the server stopped (that was the reason
    # --model / --verify-model completed to nothing). Falls back to a live query
    # only if the cache is cold. With --claude, also offers the Claude CLI aliases,
    # since the verify pass is commonly a cloud model.
    argparse claude -- $argv 2>/dev/null

    set -l names (_ai_get_installed_names)
    if test -z "$names[1]"
        # Cache cold — best-effort live query (may be empty if the server is down).
        set names (ollama list 2>/dev/null | tail -n +2 | awk '{print $1}')
    end
    printf '%s\n' $names

    if set -q _flag_claude
        printf '%s\tClaude (cloud)\n' sonnet opus haiku
    end
end
