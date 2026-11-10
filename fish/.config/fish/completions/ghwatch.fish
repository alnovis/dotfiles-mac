# Completions for `ghwatch`

complete -c ghwatch -f

complete -c ghwatch -s h -l help -d 'Show help'

# Workflows from the current repo's .github/workflows (offline; for REPO, type the name)
complete -c ghwatch -s w -l workflow -x -d 'Workflow file' \
    -a '(path basename (git rev-parse --show-toplevel 2>/dev/null)/.github/workflows/*.{yml,yaml} 2>/dev/null)'

complete -c ghwatch -s t -l tag -x -d 'Tag' \
    -a '(git tag --sort=-v:refname 2>/dev/null)'
