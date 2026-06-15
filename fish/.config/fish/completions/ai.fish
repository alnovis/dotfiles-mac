# Completions for ai command

# Disable file completions by default
complete -c ai -f

# Top-level subcommands
complete -c ai -n __fish_use_subcommand -a gen -d "Generate: commit, summary"
complete -c ai -n __fish_use_subcommand -a config -d "View or set AI config"
complete -c ai -n __fish_use_subcommand -a models -d "Manage models"
complete -c ai -n __fish_use_subcommand -a review -d "AI code review"
complete -c ai -n __fish_use_subcommand -a code -d "AI-assisted coding (aider)"
complete -c ai -n __fish_use_subcommand -a chat -d "Chat (--session for persistent REPL)"
complete -c ai -n __fish_use_subcommand -a sessions -d "Manage chat sessions"
complete -c ai -n __fish_use_subcommand -a stop -d "Stop models or server"
complete -c ai -n __fish_use_subcommand -a help -d "Show help"

# Top-level flags
complete -c ai -n __fish_use_subcommand -s m -l model -d "Use specific model" -x -a "(ollama list 2>/dev/null | tail -n +2 | awk '{print \$1}')"
complete -c ai -n __fish_use_subcommand -s t -l think -d "Enable thinking mode"
complete -c ai -n __fish_use_subcommand -l provider -d "Override provider" -x -a "(_ai_providers)"
complete -c ai -n __fish_use_subcommand -l dry-run -d "Print assembled prompt without invoking the model"
complete -c ai -n __fish_use_subcommand -s h -l help -d "Show help"

# --- ai gen ---
set -l gen_subcmds "commit summary"

complete -c ai -n "__fish_seen_subcommand_from gen; and not __fish_seen_subcommand_from $gen_subcmds" -a commit -d "Generate commit message"
complete -c ai -n "__fish_seen_subcommand_from gen; and not __fish_seen_subcommand_from $gen_subcmds" -a summary -d "Generate project summary"

# ai gen common flags
complete -c ai -n "__fish_seen_subcommand_from gen" -l provider -d "Override provider" -x -a "(_ai_providers)"
complete -c ai -n "__fish_seen_subcommand_from gen" -l model -d "Override model" -x -a "(ollama list 2>/dev/null | tail -n +2 | awk '{print \$1}')"
complete -c ai -n "__fish_seen_subcommand_from gen" -l lang -s l -d "Response language" -x -a "en ru fr de es pl pt it nl ja ko zh uk cs sv tr ar"
complete -c ai -n "__fish_seen_subcommand_from gen" -s o -l output -d "Save output to file" -rF
complete -c ai -n "__fish_seen_subcommand_from gen" -l dry-run -d "Print assembled prompt without invoking the model"

# ai gen summary: allow directory completion
complete -c ai -n "__fish_seen_subcommand_from gen; and __fish_seen_subcommand_from summary" -a "(__fish_complete_directories)" -d "Project directory"

# --- ai config ---
set -l config_subcmds "provider reset tasks status move"
complete -c ai -n "__fish_seen_subcommand_from config; and not __fish_seen_subcommand_from $config_subcmds" -a provider -d "Default AI provider"
complete -c ai -n "__fish_seen_subcommand_from config; and not __fish_seen_subcommand_from $config_subcmds" -a reset -d "Clear per-task provider+model"
complete -c ai -n "__fish_seen_subcommand_from config; and not __fish_seen_subcommand_from $config_subcmds" -a tasks -d "List known tasks"
complete -c ai -n "__fish_seen_subcommand_from config; and not __fish_seen_subcommand_from $config_subcmds" -a status -d "Resolved per-task view with origin"
complete -c ai -n "__fish_seen_subcommand_from config; and not __fish_seen_subcommand_from $config_subcmds" -a move -d "Move per-task keys between project and global"
complete -c ai -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from provider" -x -a "(_ai_providers)"
complete -c ai -n "__fish_seen_subcommand_from config" -l task -d "Per-task scope (comma-list or 'all')" -x -a "(_ai_tasks; echo all)"
complete -c ai -n "__fish_seen_subcommand_from config" -l project -d "Write/clear in project .ai/config (default: global)"
complete -c ai -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from move" -l to -d "Target layer" -x -a "project global"

# --- ai models ---
set -l models_subcmds "list install rm use update info prune running"

complete -c ai -n "__fish_seen_subcommand_from models; and not __fish_seen_subcommand_from $models_subcmds" -a list -d "Show available models"
complete -c ai -n "__fish_seen_subcommand_from models; and not __fish_seen_subcommand_from $models_subcmds" -a install -d "Download a model"
complete -c ai -n "__fish_seen_subcommand_from models; and not __fish_seen_subcommand_from $models_subcmds" -a rm -d "Remove a model"
complete -c ai -n "__fish_seen_subcommand_from models; and not __fish_seen_subcommand_from $models_subcmds" -a use -d "Set default model"
complete -c ai -n "__fish_seen_subcommand_from models; and not __fish_seen_subcommand_from $models_subcmds" -a update -d "Update all models"
complete -c ai -n "__fish_seen_subcommand_from models; and not __fish_seen_subcommand_from $models_subcmds" -a info -d "Show model details"
complete -c ai -n "__fish_seen_subcommand_from models; and not __fish_seen_subcommand_from $models_subcmds" -a prune -d "Clean up disk"
complete -c ai -n "__fish_seen_subcommand_from models; and not __fish_seen_subcommand_from $models_subcmds" -a running -d "Show running models"

# ai models list flags
complete -c ai -n "__fish_seen_subcommand_from models; and __fish_seen_subcommand_from list" -l all -d "Show all models"

# ai models install/rm/use/info — complete with installed model names
complete -c ai -n "__fish_seen_subcommand_from models; and __fish_seen_subcommand_from rm use info" -x -a "(ollama list 2>/dev/null | tail -n +2 | awk '{print \$1}')"

# ai models use --task TASK / --project
complete -c ai -n "__fish_seen_subcommand_from models; and __fish_seen_subcommand_from use" -l task -d "Set per-task instead of global" -x -a "(_ai_tasks; echo all)"
complete -c ai -n "__fish_seen_subcommand_from models; and __fish_seen_subcommand_from use" -l project -d "Write to project .ai/config (requires --task)"

# --- ai review (unified: target mode and git mode) ---
complete -c ai -n "__fish_seen_subcommand_from review" -l model -d "Override model" -x -a "(ollama list 2>/dev/null | tail -n +2 | awk '{print \$1}')"
complete -c ai -n "__fish_seen_subcommand_from review" -l provider -d "Override provider" -x -a "(_ai_providers)"
complete -c ai -n "__fish_seen_subcommand_from review" -s o -l output -d "Save output to file" -rF
complete -c ai -n "__fish_seen_subcommand_from review" -l brief -d "Short summary"
complete -c ai -n "__fish_seen_subcommand_from review" -l dry-run -d "Print assembled prompt without invoking the model"
complete -c ai -n "__fish_seen_subcommand_from review" -l lang -d "Response language" -x -a "en ru fr de es pl pt it nl ja ko zh uk cs sv tr ar"
# git-mode-only flags
complete -c ai -n "__fish_seen_subcommand_from review" -l lang-all -d "Full response + thinking in language (git mode)" -x -a "en ru fr de es pl pt it nl ja ko zh uk cs sv tr ar"
complete -c ai -n "__fish_seen_subcommand_from review" -l last -d "Review last N commits (git mode)"
complete -c ai -n "__fish_seen_subcommand_from review" -l commit -d "Review specific commit (git mode)"
complete -c ai -n "__fish_seen_subcommand_from review" -l file -d "Filter diff to one file (git mode)" -rF
# target-mode-only flag
complete -c ai -n "__fish_seen_subcommand_from review" -l with-project-context -d "Include parent project context (target mode, file)"
# positional: dir or file (target mode)
complete -c ai -n "__fish_seen_subcommand_from review" -a "(__fish_complete_directories)" -d "Project directory"
complete -c ai -n "__fish_seen_subcommand_from review" -F -d "File to review"

# --- ai code ---
complete -c ai -n "__fish_seen_subcommand_from code" -F
complete -c ai -n "__fish_seen_subcommand_from code" -s e -l edit -d "Allow code editing"
complete -c ai -n "__fish_seen_subcommand_from code" -l model -d "Override model" -x -a "(ollama list 2>/dev/null | tail -n +2 | awk '{print \$1}')"

# --- ai stop ---
complete -c ai -n "__fish_seen_subcommand_from stop" -l server -d "Kill Ollama server entirely"
complete -c ai -n "__fish_seen_subcommand_from stop" -x -a "(ollama ps 2>/dev/null | tail -n +2 | awk '{print \$1}')"

# --- ai chat ---
complete -c ai -n "__fish_seen_subcommand_from chat" -x -a "(ollama list 2>/dev/null | tail -n +2 | awk '{print \$1}')"
complete -c ai -n "__fish_seen_subcommand_from chat" -s s -l session -d "Start/resume named session (ollama only)" -x -a "(_ai_session_names)"
complete -c ai -n "__fish_seen_subcommand_from chat" -s c -l continue -d "Continue last session"
complete -c ai -n "__fish_seen_subcommand_from chat" -l global -d "Force global scope for new session"
complete -c ai -n "__fish_seen_subcommand_from chat" -l new -d "Error if session NAME already exists"
complete -c ai -n "__fish_seen_subcommand_from chat" -l system -d "System prompt (applied at session creation)" -x
complete -c ai -n "__fish_seen_subcommand_from chat" -l model -d "Override model" -x -a "(ollama list 2>/dev/null | tail -n +2 | awk '{print \$1}')"

# --- ai sessions ---
set -l sessions_subcmds "ls show info rm rename branch archive restore edit export import clear pin unpin move search stats"
complete -c ai -n "__fish_seen_subcommand_from sessions; and not __fish_seen_subcommand_from $sessions_subcmds" -a ls -d "List sessions"
complete -c ai -n "__fish_seen_subcommand_from sessions; and not __fish_seen_subcommand_from $sessions_subcmds" -a show -d "Render as markdown"
complete -c ai -n "__fish_seen_subcommand_from sessions; and not __fish_seen_subcommand_from $sessions_subcmds" -a info -d "Meta + token stats"
complete -c ai -n "__fish_seen_subcommand_from sessions; and not __fish_seen_subcommand_from $sessions_subcmds" -a rm -d "Delete session"
complete -c ai -n "__fish_seen_subcommand_from sessions; and not __fish_seen_subcommand_from $sessions_subcmds" -a rename -d "Rename session"
complete -c ai -n "__fish_seen_subcommand_from sessions; and not __fish_seen_subcommand_from $sessions_subcmds" -a branch -d "Fork a session"
complete -c ai -n "__fish_seen_subcommand_from sessions; and not __fish_seen_subcommand_from $sessions_subcmds" -a archive -d "Hide from default ls"
complete -c ai -n "__fish_seen_subcommand_from sessions; and not __fish_seen_subcommand_from $sessions_subcmds" -a restore -d "Un-archive"
complete -c ai -n "__fish_seen_subcommand_from sessions; and not __fish_seen_subcommand_from $sessions_subcmds" -a edit -d "Open in \$EDITOR"
complete -c ai -n "__fish_seen_subcommand_from sessions; and not __fish_seen_subcommand_from $sessions_subcmds" -a export -d "Export to file"
complete -c ai -n "__fish_seen_subcommand_from sessions; and not __fish_seen_subcommand_from $sessions_subcmds" -a import -d "Import from file"
complete -c ai -n "__fish_seen_subcommand_from sessions; and not __fish_seen_subcommand_from $sessions_subcmds" -a clear -d "Wipe messages (keep meta)"
complete -c ai -n "__fish_seen_subcommand_from sessions; and not __fish_seen_subcommand_from $sessions_subcmds" -a pin -d "Lock provider/model"
complete -c ai -n "__fish_seen_subcommand_from sessions; and not __fish_seen_subcommand_from $sessions_subcmds" -a unpin -d "Revert pin"
complete -c ai -n "__fish_seen_subcommand_from sessions; and not __fish_seen_subcommand_from $sessions_subcmds" -a move -d "Move between project/global"
complete -c ai -n "__fish_seen_subcommand_from sessions; and not __fish_seen_subcommand_from $sessions_subcmds" -a search -d "Find query across messages"
complete -c ai -n "__fish_seen_subcommand_from sessions; and not __fish_seen_subcommand_from $sessions_subcmds" -a stats -d "Aggregated counts + token totals"

# Session NAME completion (for commands that take a session name)
complete -c ai -n "__fish_seen_subcommand_from sessions; and __fish_seen_subcommand_from show info rm rename branch archive edit export clear pin unpin move" -x -a "(_ai_session_names)"
complete -c ai -n "__fish_seen_subcommand_from sessions; and __fish_seen_subcommand_from rm clear" -s f -l force -d "Skip confirmation"
complete -c ai -n "__fish_seen_subcommand_from sessions; and __fish_seen_subcommand_from ls" -s a -l all -d "Include archived"
complete -c ai -n "__fish_seen_subcommand_from sessions; and __fish_seen_subcommand_from ls" -l archived -d "Show only archived"
complete -c ai -n "__fish_seen_subcommand_from sessions; and __fish_seen_subcommand_from export" -s f -l format -x -a "md json jsonl" -d "Output format"
complete -c ai -n "__fish_seen_subcommand_from sessions; and __fish_seen_subcommand_from import" -l name -x -d "Override session name"
complete -c ai -n "__fish_seen_subcommand_from sessions; and __fish_seen_subcommand_from import move" -l global -d "Target global scope"
complete -c ai -n "__fish_seen_subcommand_from sessions; and __fish_seen_subcommand_from pin" -l provider -x -a "(_ai_providers)" -d "Pin provider"
complete -c ai -n "__fish_seen_subcommand_from sessions; and __fish_seen_subcommand_from pin" -l model -x -a "(ollama list 2>/dev/null | tail -n +2 | awk '{print \$1}')" -d "Pin model"
complete -c ai -n "__fish_seen_subcommand_from sessions; and __fish_seen_subcommand_from move" -l to -x -a "project global" -d "Target scope"
complete -c ai -n "__fish_seen_subcommand_from sessions; and __fish_seen_subcommand_from search" -l name -x -d "Filter sessions by name pattern"
complete -c ai -n "__fish_seen_subcommand_from sessions; and __fish_seen_subcommand_from search" -l since -x -d "Filter sessions updated since YYYY-MM-DD"
complete -c ai -n "__fish_seen_subcommand_from sessions; and __fish_seen_subcommand_from search stats" -s a -l all -d "Include archived"
complete -c ai -n "__fish_seen_subcommand_from sessions; and __fish_seen_subcommand_from search stats" -l archived -d "Include archived"
