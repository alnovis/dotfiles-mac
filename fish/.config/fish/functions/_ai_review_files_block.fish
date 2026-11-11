function _ai_review_files_block --description "Emit the full content of a directory's files as a prompt block"
    # Args: DIR PATH...   (paths relative to DIR, from _ai_review_dir_files)
    # The target-mode counterpart of _ai_review_context_block: files come from the working
    # tree, not from a commit. The same block is handed to the verify pass as its code.
    set -l dir $argv[1]
    set -l paths $argv[2..-1]
    test (count $paths) -eq 0; and return 0

    echo "# Files"
    echo "The complete content of every file under review, as it is on disk now. Cite findings as path:line using the paths below."
    echo "Each line starts with its line number in the file and two spaces: cite these numbers, do not count lines. The number is not part of the code — quote code without it."
    for path in $paths
        set -l content (cat $dir/$path 2>/dev/null | string collect)
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
