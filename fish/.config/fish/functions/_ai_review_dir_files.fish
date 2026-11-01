function _ai_review_dir_files --description "List a directory's files eligible for full-content embedding as 'lines<TAB>path'"
    # Args: DIR
    # Emits one line per embeddable file: "<lines><TAB><path relative to DIR>". In a git
    # repo the list is `git ls-files` (so .gitignore'd build output stays out); elsewhere
    # a find that prunes the same directories `tree` hides. Skips binary and empty files.
    set -l dir $argv[1]

    set -l paths
    if git -C $dir rev-parse --is-inside-work-tree >/dev/null 2>&1
        set paths (git -C $dir ls-files -z | string split0)
    else
        set paths (find $dir \( -name node_modules -o -name target -o -name .git -o -name .idea \
            -o -name __pycache__ -o -name dist -o -name build -o -name out -o -name .cache \) -prune \
            -o -type f -print 2>/dev/null | string replace -- "$dir/" '')
    end

    for path in $paths
        set -l file $dir/$path
        test -f $file; or continue
        # grep -I treats binary as no match; an empty file has no line to match either
        grep -Iq . $file 2>/dev/null; or continue
        printf '%s\t%s\n' (wc -l <$file | string trim) $path
    end
end
