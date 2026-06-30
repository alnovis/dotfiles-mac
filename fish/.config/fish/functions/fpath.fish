function fpath --description "Print absolute path(s) of a file found recursively under a directory (pwd for files)"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: fpath [DIR] NAME"
        echo ""
        echo "Print the absolute path of NAME, searched recursively below DIR"
        echo "(default: current directory). Like 'pwd', but for a file."
        echo ""
        echo "NAME is matched as a glob against the file name, so exact names"
        echo "and patterns both work. Ignored/hidden files are included."
        echo "Every match is printed on its own line (pipe-friendly)."
        echo ""
        echo "If NAME carries a path prefix, that prefix is folded into the"
        echo "search directory and only its basename is searched below it."
        echo ""
        echo "Examples:"
        echo "  fpath gitlab.log                  # -> /Users/you/work/.../gitlab.log"
        echo "  fpath ~/work '*.log'              # search a specific dir"
        echo "  fpath ../project/docs/notes.md    # prefix sets the search dir"
        echo "  set log (fpath gitlab.log)"
        return 0
    end

    set -l dir .
    set -l name
    switch (count $argv)
        case 0
            echo "fpath: missing file name (try 'fpath --help')" >&2
            return 2
        case 1
            set name $argv[1]
        case '*'
            set dir $argv[1]
            set name $argv[2]
    end

    # A path prefix on the file name (e.g. ../project/docs/notes.md) is
    # peeled off and folded into the search dir, so the recursive search runs
    # below that dir for the bare basename. No cd: paths are just joined.
    set -l name_dir (path dirname -- "$name")
    if test "$name_dir" != .
        set name (path basename -- "$name")
        if string match -q '/*' -- "$name_dir"
            set dir "$name_dir" # absolute prefix wins, like path joining
        else if test "$dir" = .
            set dir "$name_dir"
        else
            set dir "$dir/$name_dir"
        end
    end

    if not test -d "$dir"
        echo "fpath: not a directory: $dir" >&2
        return 2
    end

    set -l matches
    if type -q fd
        set matches (fd --absolute-path --type f --hidden --no-ignore --glob -- "$name" "$dir")
    else
        # Resolve dir to an absolute base so find prints absolute paths.
        set -l base (cd "$dir"; and pwd)
        set matches (find "$base" -type f -name "$name" 2>/dev/null)
    end

    if test (count $matches) -eq 0
        echo "fpath: no file matching '$name' under $dir" >&2
        return 1
    end

    printf '%s\n' $matches
end
