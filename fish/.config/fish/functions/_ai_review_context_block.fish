function _ai_review_context_block --description "Emit full content of the given changed files as a prompt block"
    # Args: TIP PATH...
    # Emits a fenced section per file so a single-shot model sees whole files
    # (the entire class / pom.xml / Cargo.toml), not just the diff hunks.
    set -l tip $argv[1]
    set -l paths $argv[2..-1]
    test (count $paths) -eq 0; and return 0

    echo "# Full content of the changed files (context beyond the diff)"
    echo "These are the complete files as of the reviewed change. Use them to reason about code the diff does not show (surrounding methods, fields, config). Do not review unchanged lines as if they were introduced here."
    echo "Each line starts with its line number in the file and two spaces: cite these numbers, do not count lines. The number is not part of the code — quote code without it."
    for path in $paths
        set -l content (git show "$tip:$path" 2>/dev/null | string collect)
        test -z "$content"; and continue
        # The extension of the file name, not of the path: "nvim/.config/nvim/LICENSE" gave
        # the fence "config/nvim/LICENSE"
        set -l name (path basename -- $path)
        set -l ext ""
        string match -q '*.*' -- $name; and set ext (string match -r '[^.]+$' -- $name)
        set -l fence (_ai_md_fence "$content")
        printf '\n## %s\n%s%s\n%s\n%s\n' $path $fence $ext (printf '%s\n' "$content" | _ai_number_lines | string collect) $fence
    end
end
