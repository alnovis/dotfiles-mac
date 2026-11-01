function take --description "Create directory and cd into it, or clone/extract and cd"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: take <path|url|archive>"
        echo ""
        echo "Create a directory and cd into it."
        echo ""
        echo "Supports:"
        echo "  take some/path       mkdir -p + cd"
        echo "  take repo.git        git clone + cd"
        echo "  take archive.tar.gz  extract + cd"
        echo ""
        echo "Recognized archives: .tar.gz .tgz .tar.bz2 .tar.xz .tar .zip"
        echo "Recognized git URLs: https://*.git, git@*, gh:user/repo"
        return 0
    end

    if test (count $argv) -ne 1
        echo "Usage: take <path|url|archive>"
        return 1
    end

    set -l target $argv[1]

    # --- Git URL ---
    if string match -rq '\.git$' $target
        or string match -rq '^git@' $target
        or string match -rq '^gh:' $target
        _take_clone $target
        return $status
    end

    # --- Archive ---
    if string match -rq '\.(tar\.gz|tgz|tar\.bz2|tar\.xz|tar|zip)$' $target
        _take_extract $target
        return $status
    end

    # --- Directory ---
    if test -d $target
        cd $target
        return 0
    end

    if not mkdir -p $target
        set_color red
        echo "Error: failed to create $target"
        set_color normal
        return 1
    end

    cd $target
end

function _take_clone
    set -l url $argv[1]

    # gh:user/repo → https://github.com/user/repo.git
    if string match -rq '^gh:' $url
        set url "https://github.com/"(string replace 'gh:' '' $url)".git"
    end

    if not git clone $url
        set_color red
        echo "Error: git clone failed"
        set_color normal
        return 1
    end

    # Derive directory name from URL
    set -l dirname (basename $url .git)
    if not test -d $dirname
        set_color red
        echo "Error: expected directory $dirname not found after clone"
        set_color normal
        return 1
    end

    cd $dirname
end

function _take_extract
    set -l archive $argv[1]

    if not test -f $archive
        set_color red
        echo "Error: file not found: $archive"
        set_color normal
        return 1
    end

    # Resolve to absolute path before creating extract dir
    set -l archive_path (realpath $archive)
    set -l dirname (_take_archive_dirname $archive)

    mkdir -p $dirname; or return 1

    # Strip the top directory only when the tarball has exactly one: on a flat archive
    # (files at the top level) --strip-components=1 extracts nothing and still succeeds
    set -l strip
    if string match -qr '\.(tar(\.(gz|bz2|xz))?|tgz)$' -- $archive
        set -l tops (tar tf $archive_path 2>/dev/null | string replace -r '^\./' '' | string match -v '' | string replace -r '/.*' '' | sort -u)
        set -l nested (tar tf $archive_path 2>/dev/null | string replace -r '^\./' '' | string match -r '^[^/]+/.')
        if test (count $tops) -eq 1; and test (count $nested) -gt 0
            set strip --strip-components=1
        end
    end

    set -l rc 0
    switch $archive
        case '*.tar.gz' '*.tgz'
            tar xzf $archive_path -C $dirname $strip; or set rc 1
        case '*.tar.bz2'
            tar xjf $archive_path -C $dirname $strip; or set rc 1
        case '*.tar.xz'
            tar xJf $archive_path -C $dirname $strip; or set rc 1
        case '*.tar'
            tar xf $archive_path -C $dirname $strip; or set rc 1
        case '*.zip'
            # zip doesn't have --strip-components, extract then move
            set -l tmpdir (mktemp -d)
            if not unzip -q $archive_path -d $tmpdir
                rm -rf $tmpdir
                set_color red
                echo "Error: unzip failed"
                set_color normal
                return 1
            end
            # If archive has a single root dir, use its contents
            set -l entries $tmpdir/*/
            if test (count $entries) -eq 1
                command mv $entries[1]/* $dirname/ 2>/dev/null; or set rc 1
                # dotfiles: a no-match glob is fine, so this one doesn't count
                command mv $entries[1]/.* $dirname/ 2>/dev/null
            else
                command mv $tmpdir/* $dirname/ 2>/dev/null; or set rc 1
            end
            rm -rf $tmpdir
    end

    if test $rc -ne 0
        set_color red
        echo "Error: extraction failed"
        set_color normal
        return 1
    end

    cd $dirname
end

function _take_archive_dirname
    set -l name (basename $argv[1])
    # Strip known extensions
    set name (string replace -r '\.(tar\.gz|tgz|tar\.bz2|tar\.xz|tar|zip)$' '' $name)
    echo $name
end
