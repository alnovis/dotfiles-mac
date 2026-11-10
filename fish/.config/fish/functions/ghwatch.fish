function ghwatch --description "Watch a GitHub Actions run until it finishes (default workflow: release.yml)"
    argparse 'h/help' 'w/workflow=' 't/tag=' -- $argv; or return 1

    if set -q _flag_help
        echo "Usage: ghwatch [OPTIONS] [REPO]"
        echo ""
        echo "Watch a GitHub Actions run until it finishes; exits non-zero if it failed."
        echo "Inside a repo, picks the run for the HEAD commit and waits for it to"
        echo "appear, so it is safe to run right after a push."
        echo ""
        echo "REPO is OWNER/NAME; if omitted, gh takes it from the current repo's remote."
        echo "With REPO and no --tag, watches the workflow's latest run."
        echo ""
        echo "Options:"
        echo "  -w, --workflow FILE  Workflow file or name (default: release.yml)"
        echo "  -t, --tag TAG        Watch the run for this tag (or branch)"
        echo "  -h, --help           Show this help"
        echo ""
        echo "Examples:"
        echo "  ghwatch                   Release run for the HEAD commit"
        echo "  ghwatch -w ci.yml         CI run for the HEAD commit"
        echo "  ghwatch -t v1.2.3         Release run for tag v1.2.3"
        echo "  ghwatch owner/project     Latest release run of another repo"
        return 0
    end

    if test (count $argv) -gt 1
        echo "Usage: ghwatch [OPTIONS] [REPO]"
        return 1
    end

    set -l repo_args
    if test (count $argv) -eq 1
        set repo_args -R $argv[1]
    end

    set -l workflow release.yml
    if set -q _flag_workflow
        set workflow $_flag_workflow
    end

    # Which run: the tag's, else (inside the repo) the HEAD commit's, else just the latest.
    # The filter is what makes it safe right after a push: `--limit 1` alone returns the
    # previous run until GitHub registers the new one.
    set -l filter
    set -l target
    if set -q _flag_tag
        set filter --branch $_flag_tag
        set target $_flag_tag
    else if test -z "$repo_args"
        set -l head (git rev-parse HEAD 2>/dev/null)
        if test $status -ne 0
            echo "Not a git repository — run inside one or pass REPO"
            return 1
        end
        set filter --commit $head
        set target (git rev-parse --short HEAD)
    end

    set -l run
    set -l waited 0
    set -l timeout 60
    while true
        # Status checked on the gh line itself: `string split` below fails on empty input
        set -l line (gh run list $repo_args --workflow $workflow $filter --limit 1 \
            --json databaseId,headBranch,url \
            -q '.[0] | select(.) | "\(.databaseId)\t\(.headBranch)\t\(.url)"')
        or return 1 # gh already said why (unknown repo/workflow, auth)

        if test -n "$line"
            set run (string split \t -- $line)
            break
        end

        if test -z "$filter"
            echo "No runs of $workflow"
            return 1
        end
        if test $waited -ge $timeout
            set_color red
            echo "No $workflow run for $target after $timeout seconds — pushed? does $workflow trigger on it?"
            set_color normal
            return 1
        end
        if test $waited -eq 0
            echo "Waiting for a $workflow run for $target..."
        end
        sleep 3
        set waited (math $waited + 3)
    end

    set_color cyan
    echo "Watching $workflow run $run[1] ($run[2])"
    set_color normal
    echo $run[3]
    gh run watch $repo_args --exit-status $run[1]
end
