function grelease --description "Tag a release: commit, tag, push (with re-release support)"
    argparse 'h/help' 'no-commit' 'no-push' -- $argv; or return 1

    if set -q _flag_help
        echo "Usage: grelease [OPTIONS] [VERSION] [MESSAGE]"
        echo ""
        echo "Create or re-release a git tag. Stages all changes, commits,"
        echo "creates tag, and pushes."
        echo ""
        echo "VERSION can be:"
        echo "  v1.2.3 / 1.2.3    Explicit version"
        echo "  patch              Bump patch (default if omitted)"
        echo "  minor              Bump minor version"
        echo "  major              Bump major version"
        echo ""
        echo "Options:"
        echo "      --no-commit   Skip commit (tag current HEAD)"
        echo "      --no-push     Skip push to remote"
        echo "  -h, --help        Show this help"
        echo ""
        echo "Examples:"
        echo "  grelease v0.2.37 \"analytics fixes\"   Commit + tag + push"
        echo "  grelease v0.2.36 \"hotfix\"             Re-release (deletes old tag)"
        echo "  grelease                              Auto-bump patch"
        echo "  grelease minor \"new feature\"          Bump minor version"
        return 0
    end

    set -l repo_root (git rev-parse --show-toplevel 2>/dev/null)
    if test $status -ne 0
        echo "Not a git repository"
        return 1
    end

    set -l repo_name (basename $repo_root)
    set -l branch (git branch --show-current)

    # Find latest semver tag
    set -l all_tags (git tag --sort=-v:refname | string match -r '^v\d+\.\d+\.\d+$')
    set -l latest_tag ""
    if test (count $all_tags) -gt 0
        set latest_tag $all_tags[1]
    end

    set -l cur_major 0
    set -l cur_minor 0
    set -l cur_patch 0
    if test -n "$latest_tag"
        set -l ver (string replace 'v' '' $latest_tag)
        set -l parts (string split '.' $ver)
        set cur_major $parts[1]
        set cur_minor $parts[2]
        set cur_patch $parts[3]
    end

    # Parse: [VERSION] [MESSAGE]
    set -l version
    set -l message

    if test (count $argv) -ge 1
        switch $argv[1]
            case patch
                set version "v$cur_major.$cur_minor."(math $cur_patch + 1)
            case minor
                set version "v$cur_major."(math $cur_minor + 1)".0"
            case major
                set version "v"(math $cur_major + 1)".0.0"
            case '*'
                set version $argv[1]
                if not string match -q 'v*' $version
                    set version "v$version"
                end
        end
        if test (count $argv) -ge 2
            set message $argv[2]
        end
    else
        set version "v$cur_major.$cur_minor."(math $cur_patch + 1)
    end

    # Validate version format
    if not string match -rq '^v\d+\.\d+\.\d+$' $version
        set_color red
        echo "Invalid version format: $version (expected: v1.2.3)"
        set_color normal
        return 1
    end

    # Check if tag already exists (re-release)
    set -l is_rerelease false
    if git rev-parse "$version" >/dev/null 2>&1
        set is_rerelease true
    end

    # Check for changes
    set -l porcelain (git status --porcelain 2>/dev/null | string collect)
    set -l has_changes false
    if test -n "$porcelain"
        set has_changes true
    end

    # Determine if we will commit
    set -l will_commit false
    if test "$has_changes" = true; and not set -q _flag_no_commit
        set will_commit true
    end

    # Nothing to do check
    if test "$has_changes" = false -a "$is_rerelease" = false
        set -l head_tags (git tag --points-at HEAD 2>/dev/null)
        if string match -q "$version" $head_tags
            echo "Repository: $repo_name ($branch)"
            echo "HEAD is already tagged $version"
            return 0
        end
    end

    # Ask for commit message interactively if not provided
    if test "$will_commit" = true -a -z "$message"
        echo "Repository: $repo_name ($branch)"
        echo ""
        git -c color.status=always status --short | while read -l line
            echo "  $line"
        end
        echo ""
        read -l -P "Release description (optional): " message
    end

    # Build commit message
    set -l commit_msg "$version"
    if test -n "$message"
        set commit_msg "$version: $message"
    end

    # --- Show plan ---
    echo "Repository: $repo_name ($branch)"

    if test -n "$latest_tag"
        echo "Latest tag: $latest_tag"
    else
        echo "Latest tag: (none)"
    end

    set_color cyan
    echo "Release: $version"
    set_color normal

    if test "$is_rerelease" = true
        set_color yellow
        echo "Re-release: tag $version will be deleted and recreated"
        set_color normal
    end

    if test "$will_commit" = true
        echo ""
        set_color green
        echo "Changes:"
        set_color normal
        git -c color.status=always status --short | while read -l line
            echo "  $line"
        end
        echo ""
        echo "Commit: $commit_msg"
    else if set -q _flag_no_commit
        echo "Tagging current HEAD (no commit)"
    else if test "$has_changes" = false
        echo "No changes — tagging current HEAD"
    end

    # Confirmation
    echo ""
    read -l -P "Proceed? (y/N) " confirm
    if test "$confirm" != y -a "$confirm" != Y
        echo "Aborted"
        return 1
    end

    # --- Execute ---

    # 1. Delete old tag if re-release
    if test "$is_rerelease" = true
        echo "Deleting old tag $version..."
        git tag -d $version
        git push origin :refs/tags/$version 2>/dev/null
    end

    # 2. Commit if needed
    if test "$will_commit" = true
        git add -A
        if not git commit -m "$commit_msg"
            set_color red
            echo "Error: commit failed"
            set_color normal
            return 1
        end
    end

    # 3. Create tag
    if not git tag $version
        set_color red
        echo "Error: failed to create tag $version"
        set_color normal
        return 1
    end

    # 4. Push
    if not set -q _flag_no_push
        echo "Pushing..."
        if not git push
            set_color red
            echo "Error: push failed"
            set_color normal
            return 1
        end
        if not git push --tags
            set_color red
            echo "Error: tag push failed"
            set_color normal
            return 1
        end
    end

    echo "---"
    set_color green
    echo "Released $version"
    set_color normal
    if set -q _flag_no_push
        echo "Push skipped — run: git push && git push --tags"
    end
end
