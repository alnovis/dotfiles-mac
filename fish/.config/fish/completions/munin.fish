# Completions for munin (local memory for AI coding agents)
#
# munin has no completion generator of its own, so the tree below mirrors
# `munin <cmd> --help`. Groups, projects, tags and entry ids are read live
# from `munin --json` (needs jq).

# Positional words typed so far: the subcommand path and its arguments,
# without options and their values
function __munin_words
    set -l value_opts --db --scope --group --project --limit --kind --summary \
        --body --body-file --tag --supersedes --reason
    set -l skip 0
    for t in (commandline -opc)[2..]
        if test $skip -eq 1
            set skip 0
            continue
        end
        switch $t
            case '--*=*'
                continue
            case '-*'
                contains -- $t $value_opts; and set skip 1
                continue
        end
        echo $t
    end
end

# True when the positional words are exactly $argv (`__munin_at` = no subcommand yet)
function __munin_at
    set -l words (__munin_words)
    test "$words" = "$argv"
end

# True when the subcommand path starts with $argv
function __munin_in
    set -l words (__munin_words)
    set -l n (count $argv)
    test (count $words) -ge $n; or return 1
    test "$words[1..$n]" = "$argv"
end

# True when at least $argv[1] positional words are typed
function __munin_nwords
    test (count (__munin_words)) -ge $argv[1]
end

function __munin_groups
    munin --json group list 2>/dev/null \
        | jq -r '.[] | "\(.name)\t\(.members | join(", "))"' 2>/dev/null
end

function __munin_projects
    begin
        munin --json group list | jq -r '.[].members[]'
        munin --json list --scope all --inactive | jq -r '.[].owner.project // empty'
    end 2>/dev/null | sort -u
end

function __munin_tags
    munin --json tags --scope all --limit 200 2>/dev/null \
        | jq -r '.[] | "\(.tag)\t\(.total) entr\(if .total == 1 then "y" else "ies" end)"' 2>/dev/null
end

# Entry ids, newest first; extra args go to `munin list` (e.g. --inactive)
function __munin_ids
    munin --json list --scope all --limit 100 $argv 2>/dev/null \
        | jq -r '.[] | "\(.id)\t\(if .status != "active" then "[\(.status)] " else "" end)\(.kind): \(.summary[0:70])"' 2>/dev/null
end

# Value lists with descriptions, one "value<TAB>description" per line
function __munin_scopes
    printf '%s\t%s\n' \
        project 'This project only' \
        group 'The project and its group' \
        all Everything
end

function __munin_kinds
    printf '%s\t%s\n' \
        decision 'Choice or convention, never fades' \
        architecture 'How the system is built, never fades' \
        bugfix 'Problem, cause and fix, fades' \
        note 'Anything else, fades' \
        howto 'Steps to do something again, never fades'
end

# Register "name:description" pairs as subcommands under condition $argv[1]
function __munin_subs -a cond
    for pair in $argv[2..]
        set -l kv (string split -m1 : -- $pair)
        complete -c munin -n $cond -a $kv[1] -d $kv[2]
    end
end

complete -c munin -f

# Global options, accepted at every level
complete -c munin -l db -r -F -d 'Database file (env MUNIN_DB, default ~/.munin/munin.db)'
complete -c munin -l json -d 'Print JSON instead of text'
complete -c munin -s h -l help -d 'Print help'
complete -c munin -n __munin_at -s V -l version -d 'Print version'

# Subcommands
set -l top \
    'search:Search memory (words OR-ed, "quoted phrase" in order)' \
    'show:Show one entry with its chain and events' \
    'add:Record a new entry' \
    'retract:Mark an entry as wrong' \
    'tags:List tags in use, most recent first' \
    'list:List every entry in scope, newest first' \
    'brief:Summarise memory for the current project' \
    'config:Show the task number formats in effect' \
    'protocol:Print the protocol agents follow' \
    'serve:Run the MCP server on stdio' \
    'group:Manage groups of projects' \
    'hook:Claude Code hooks' \
    'help:Print help of a subcommand'
__munin_subs __munin_at $top
__munin_subs '__munin_at help' $top

# Options shared by the scoped subcommands
for sub in search tags list
    complete -c munin -n "__munin_in $sub" -l scope -x -a '(__munin_scopes)' -d 'Where to look'
    complete -c munin -n "__munin_in $sub" -l group -x -a '(__munin_groups)' -d 'Look in this group and its projects'
end
for sub in search tags list brief add
    complete -c munin -n "__munin_in $sub" -l project -x -a '(__munin_projects)' -d 'Current project (env MUNIN_PROJECT)'
end

# search
complete -c munin -n '__munin_in search' -l inactive -d 'Include superseded and retracted entries'
complete -c munin -n '__munin_in search' -l deep -d 'Rank on text alone, ignoring age'
complete -c munin -n '__munin_in search' -l limit -x -d 'Number of cards, 1 to 15 (default 5)'

# show
complete -c munin -n '__munin_at show' -k -a '(__munin_ids --inactive)'

# add
complete -c munin -n '__munin_in add' -l kind -x -a '(__munin_kinds)' -d 'decision, architecture, bugfix, note or howto'
complete -c munin -n '__munin_in add' -l summary -x -d 'One line, at most 200 characters'
complete -c munin -n '__munin_in add' -l body -x -d 'Context, what was tried, why'
complete -c munin -n '__munin_in add' -l body-file -r -F -d 'Read the body from a file (- for stdin)'
complete -c munin -n '__munin_in add' -l tag -x -a '(__munin_tags)' -d 'Tag (repeat, at most 6)'
complete -c munin -n '__munin_in add' -l supersedes -x -k -a '(__munin_ids)' -d 'Id of the entry this one replaces'
complete -c munin -n '__munin_in add' -l group -x -a '(__munin_groups)' -d 'Record for this group instead of the project'

# retract
complete -c munin -n '__munin_at retract' -k -a '(__munin_ids)'
complete -c munin -n '__munin_in retract' -l reason -x -d 'Why the entry is wrong'

# tags
complete -c munin -n '__munin_in tags' -l limit -x -d 'Number of tags, 1 to 200 (default 40)'

# list
complete -c munin -n '__munin_in list' -l kind -x -a '(__munin_kinds)' -d 'Only entries of this kind'
complete -c munin -n '__munin_in list' -l inactive -d 'Include superseded and retracted entries'
complete -c munin -n '__munin_in list' -l limit -x -d 'At most this many entries (default all)'

# group
set -l group \
    'add:Add projects to a group (creates it)' \
    'remove:Remove projects from a group' \
    'delete:Delete a group (refused while it owns entries)' \
    'list:List groups, or the groups of a project' \
    'help:Print help of a group subcommand'
__munin_subs '__munin_at group' $group
__munin_subs '__munin_at group help' $group
complete -c munin -n '__munin_at group add' -a '(__munin_groups)'
complete -c munin -n '__munin_in group add; and __munin_nwords 3' -a '(__munin_projects)'
complete -c munin -n '__munin_at group remove' -a '(__munin_groups)'
complete -c munin -n '__munin_in group remove; and __munin_nwords 3' -a '(__munin_projects)'
complete -c munin -n '__munin_at group delete' -a '(__munin_groups)'
complete -c munin -n '__munin_in group list' -l project -x -a '(__munin_projects)' -d 'Groups this project belongs to'

# hook
set -l hook \
    'stop:Stop hook: asks the agent once to record' \
    'pre-compact:PreCompact hook: compaction summary instructions' \
    'prompt:UserPromptSubmit hook: entries for task numbers' \
    'help:Print help of a hook subcommand'
__munin_subs '__munin_at hook' $hook
__munin_subs '__munin_at hook help' $hook
