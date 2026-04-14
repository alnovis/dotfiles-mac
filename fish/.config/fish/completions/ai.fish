# Completions for ai command

# Disable file completions by default
complete -c ai -f

# Top-level subcommands
complete -c ai -n __fish_use_subcommand -a gen -d "Generate: review, commit, summary"
complete -c ai -n __fish_use_subcommand -a config -d "View or set AI config"
complete -c ai -n __fish_use_subcommand -a models -d "Manage models"
complete -c ai -n __fish_use_subcommand -a review -d "AI code review"
complete -c ai -n __fish_use_subcommand -a code -d "AI-assisted coding (aider)"
complete -c ai -n __fish_use_subcommand -a chat -d "Chat model"
complete -c ai -n __fish_use_subcommand -a stop -d "Stop models or server"
complete -c ai -n __fish_use_subcommand -a help -d "Show help"

# Top-level flags
complete -c ai -n __fish_use_subcommand -s m -l model -d "Use specific model" -x -a "(ollama list 2>/dev/null | tail -n +2 | awk '{print \$1}')"
complete -c ai -n __fish_use_subcommand -s t -l think -d "Enable thinking mode"
complete -c ai -n __fish_use_subcommand -l provider -d "Override provider" -x -a "(_ai_providers)"
complete -c ai -n __fish_use_subcommand -s h -l help -d "Show help"

# --- ai gen ---
set -l gen_subcmds "review commit summary"

complete -c ai -n "__fish_seen_subcommand_from gen; and not __fish_seen_subcommand_from $gen_subcmds" -a review -d "Project review"
complete -c ai -n "__fish_seen_subcommand_from gen; and not __fish_seen_subcommand_from $gen_subcmds" -a commit -d "Generate commit message"
complete -c ai -n "__fish_seen_subcommand_from gen; and not __fish_seen_subcommand_from $gen_subcmds" -a summary -d "Generate project summary"

# ai gen common flags
complete -c ai -n "__fish_seen_subcommand_from gen" -l provider -d "Override provider" -x -a "(_ai_providers)"
complete -c ai -n "__fish_seen_subcommand_from gen" -l model -d "Override model" -x -a "(ollama list 2>/dev/null | tail -n +2 | awk '{print \$1}')"
complete -c ai -n "__fish_seen_subcommand_from gen" -l lang -s l -d "Response language" -x -a "en ru fr de es pl pt it nl ja ko zh uk cs sv tr ar"
complete -c ai -n "__fish_seen_subcommand_from gen" -s o -l output -d "Save output to file" -rF

# ai gen review/summary: allow directory completion
complete -c ai -n "__fish_seen_subcommand_from gen; and __fish_seen_subcommand_from review summary" -a "(__fish_complete_directories)" -d "Project directory"

# --- ai config ---
complete -c ai -n "__fish_seen_subcommand_from config; and not __fish_seen_subcommand_from provider" -a provider -d "Default AI provider"
complete -c ai -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from provider" -x -a "(_ai_providers)"

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

# --- ai review ---
complete -c ai -n "__fish_seen_subcommand_from review" -l model -d "Override model" -x -a "(ollama list 2>/dev/null | tail -n +2 | awk '{print \$1}')"
complete -c ai -n "__fish_seen_subcommand_from review" -l provider -d "Override provider" -x -a "(_ai_providers)"
complete -c ai -n "__fish_seen_subcommand_from review" -l file -d "Review specific file" -rF
complete -c ai -n "__fish_seen_subcommand_from review" -l brief -d "Short summary"
complete -c ai -n "__fish_seen_subcommand_from review" -l lang -d "Response language" -x -a "en ru fr de es pl pt it nl ja ko zh uk cs sv tr ar"
complete -c ai -n "__fish_seen_subcommand_from review" -l lang-all -d "Full response + thinking in language" -x -a "en ru fr de es pl pt it nl ja ko zh uk cs sv tr ar"
complete -c ai -n "__fish_seen_subcommand_from review" -l last -d "Review last N commits"
complete -c ai -n "__fish_seen_subcommand_from review" -l commit -d "Review specific commit"

# --- ai code ---
complete -c ai -n "__fish_seen_subcommand_from code" -F
complete -c ai -n "__fish_seen_subcommand_from code" -s e -l edit -d "Allow code editing"
complete -c ai -n "__fish_seen_subcommand_from code" -l model -d "Override model" -x -a "(ollama list 2>/dev/null | tail -n +2 | awk '{print \$1}')"

# --- ai stop ---
complete -c ai -n "__fish_seen_subcommand_from stop" -l server -d "Kill Ollama server entirely"
complete -c ai -n "__fish_seen_subcommand_from stop" -x -a "(ollama ps 2>/dev/null | tail -n +2 | awk '{print \$1}')"

# --- ai chat ---
complete -c ai -n "__fish_seen_subcommand_from chat" -x -a "(ollama list 2>/dev/null | tail -n +2 | awk '{print \$1}')"
