# Completions for ai command

# Disable file completions by default
complete -c ai -f

# Top-level subcommands
complete -c ai -n __fish_use_subcommand -a gen -d "Generate: commit, summary"
complete -c ai -n __fish_use_subcommand -a config -d "View or set AI config"
complete -c ai -n __fish_use_subcommand -a providers -d "List providers / check reachability"
complete -c ai -n "__fish_seen_subcommand_from providers; and not __fish_seen_subcommand_from ls check" -a ls -d "List providers"
complete -c ai -n "__fish_seen_subcommand_from providers; and not __fish_seen_subcommand_from ls check" -a check -d "Is it reachable now?"
complete -c ai -n "__fish_seen_subcommand_from providers; and __fish_seen_subcommand_from check" -x -a "(_ai_providers)"
complete -c ai -n __fish_use_subcommand -a models -d "Manage models"
complete -c ai -n __fish_use_subcommand -a review -d "AI code review"
complete -c ai -n __fish_use_subcommand -a code -d "Interactive coding session"
complete -c ai -n __fish_use_subcommand -a chat -d "Interactive chat (-c continue, -r resume)"
complete -c ai -n __fish_use_subcommand -a stop -d "Stop models or server"
complete -c ai -n __fish_use_subcommand -a help -d "Show help"

# Top-level flags
complete -c ai -n __fish_use_subcommand -s m -l model -d "Use specific model" -x -a "(_ai_complete_models)"
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
complete -c ai -n "__fish_seen_subcommand_from gen" -l model -d "Override model" -x -a "(_ai_complete_models)"
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
set -l models_subcmds "list info try keep drop search label use install rm update prune running"

complete -c ai -n "__fish_seen_subcommand_from models; and not __fish_seen_subcommand_from $models_subcmds" -a list -d "Installed models"
complete -c ai -n "__fish_seen_subcommand_from models; and not __fish_seen_subcommand_from $models_subcmds" -a info -d "Details (registry if not installed)"
complete -c ai -n "__fish_seen_subcommand_from models; and not __fish_seen_subcommand_from $models_subcmds" -a try -d "Pull as a trial"
complete -c ai -n "__fish_seen_subcommand_from models; and not __fish_seen_subcommand_from $models_subcmds" -a keep -d "End a trial, keep the model"
complete -c ai -n "__fish_seen_subcommand_from models; and not __fish_seen_subcommand_from $models_subcmds" -a drop -d "Remove a model and its metadata"
complete -c ai -n "__fish_seen_subcommand_from models; and not __fish_seen_subcommand_from $models_subcmds" -a search -d "Search ollama.com"
complete -c ai -n "__fish_seen_subcommand_from models; and not __fish_seen_subcommand_from $models_subcmds" -a label -d "Group a model"
complete -c ai -n "__fish_seen_subcommand_from models; and not __fish_seen_subcommand_from $models_subcmds" -a use -d "Set default / task model"
complete -c ai -n "__fish_seen_subcommand_from models; and not __fish_seen_subcommand_from $models_subcmds" -a install -d "Pull a model"
complete -c ai -n "__fish_seen_subcommand_from models; and not __fish_seen_subcommand_from $models_subcmds" -a rm -d "Remove one tag"
complete -c ai -n "__fish_seen_subcommand_from models; and not __fish_seen_subcommand_from $models_subcmds" -a update -d "Update all models"
complete -c ai -n "__fish_seen_subcommand_from models; and not __fish_seen_subcommand_from $models_subcmds" -a prune -d "Clean up disk"
complete -c ai -n "__fish_seen_subcommand_from models; and not __fish_seen_subcommand_from $models_subcmds" -a running -d "Show running models"
complete -c ai -n "__fish_seen_subcommand_from models; and not __fish_seen_subcommand_from $models_subcmds" -l provider -x -a "(_ai_providers; echo all)" -d "Models of a provider"

# installed model names
complete -c ai -n "__fish_seen_subcommand_from models; and __fish_seen_subcommand_from rm use info label keep drop" -x -a "(_ai_complete_models)"
complete -c ai -n "__fish_seen_subcommand_from models; and __fish_seen_subcommand_from try drop" -s y -l yes -d "Don't ask for confirmation"

# ai models use — TASK as the first positional (models come from the group above)
function __ai_models_use_first_arg
    set -l toks (commandline -opc)
    test (count $toks) -ge 1; and test "$toks[-1]" = use
end
complete -c ai -n __ai_models_use_first_arg -x -a "(_ai_tasks; echo all)" -d task
complete -c ai -n "__fish_seen_subcommand_from models; and __fish_seen_subcommand_from use" -l task -d "Set per-task instead of global" -x -a "(_ai_tasks; echo all)"
complete -c ai -n "__fish_seen_subcommand_from models; and __fish_seen_subcommand_from use" -l project -d "Write to project .ai/config"
complete -c ai -n "__fish_seen_subcommand_from models; and __fish_seen_subcommand_from use" -s h -l help -d "Show 'models use' help"

# --- ai review (unified: target mode and git mode) ---
complete -c ai -n "__fish_seen_subcommand_from review" -l model -d "Override model" -x -a "(_ai_complete_models)"
complete -c ai -n "__fish_seen_subcommand_from review" -l provider -d "Override provider" -x -a "(_ai_providers)"
complete -c ai -n "__fish_seen_subcommand_from review" -s o -l output -d "Save output to file" -rF
complete -c ai -n "__fish_seen_subcommand_from review" -l brief -d "Short summary"
complete -c ai -n "__fish_seen_subcommand_from review" -l agentic -d "Embed only the diff/file; the model explores the repo read-only"
complete -c ai -n "__fish_seen_subcommand_from review" -l no-think -d "Fast pass: disable a thinking model's reasoning (think:false) — trades depth for speed"
complete -c ai -n "__fish_seen_subcommand_from review" -l context-lines -d "Line budget for embedding whole files (git 2000, dir 10000; 0=none)" -x
complete -c ai -n "__fish_seen_subcommand_from review" -l lens -d "Specialist checklist(s): security, quality, Rust, Scala, Java, shell, data/messaging" -x -a "(_ai_complete_lens)"
complete -c ai -n "__fish_seen_subcommand_from review" -l no-lens -d "No lens this time, whatever review_lens says"
complete -c ai -n "__fish_seen_subcommand_from review" -l verify -d "Second-opinion verify pass"
complete -c ai -n "__fish_seen_subcommand_from review" -l no-verify -d "Disable verify (override config default)"
complete -c ai -n "__fish_seen_subcommand_from review" -l verify-provider -d "Provider for the verify pass" -x -a "(_ai_providers)"
complete -c ai -n "__fish_seen_subcommand_from review" -l verify-model -d "Model for the verify pass" -x -a "(_ai_complete_models --verify)"
complete -c ai -n "__fish_seen_subcommand_from review" -l verify-output -d "Output file for the verify pass" -r
complete -c ai -n "__fish_seen_subcommand_from review" -l verify-runs -d "Verify N times, keep each finding's majority verdict" -x -a "2 3 5"
complete -c ai -n "__fish_seen_subcommand_from review" -l verify-context -d "Verify on the code the findings cite, read beforehand" -x -a "assembled"
complete -c ai -n "__fish_seen_subcommand_from review" -l verify-only -d "Re-verify an existing review file (no review pass)" -r
complete -c ai -n "__fish_seen_subcommand_from review" -l dry-run -d "Print assembled prompt without invoking the model"
complete -c ai -n "__fish_seen_subcommand_from review" -l lang -d "Response language" -x -a "en ru fr de es pl pt it nl ja ko zh uk cs sv tr ar"
# git-mode-only flags
complete -c ai -n "__fish_seen_subcommand_from review" -l lang-all -d "Full response + thinking in language (git mode)" -x -a "en ru fr de es pl pt it nl ja ko zh uk cs sv tr ar"
complete -c ai -n "__fish_seen_subcommand_from review" -l last -d "Review last N commits (git mode)"
complete -c ai -n "__fish_seen_subcommand_from review" -l commit -d "Review specific commit (git mode)"
complete -c ai -n "__fish_seen_subcommand_from review" -l file -d "Filter diff to one file (git mode)" -rF
complete -c ai -n "__fish_seen_subcommand_from review" -l max-lines -d "Cap diff at N lines (git mode, default 500)" -x
# target-mode-only flag
complete -c ai -n "__fish_seen_subcommand_from review" -l with-project-context -d "Include parent project context (target mode, file)"
# positional: dir or file (target mode)
complete -c ai -n "__fish_seen_subcommand_from review" -a "(__fish_complete_directories)" -d "Project directory"
complete -c ai -n "__fish_seen_subcommand_from review" -F -d "File to review"

# --- ai code ---
complete -c ai -n "__fish_seen_subcommand_from code" -F
complete -c ai -n "__fish_seen_subcommand_from code" -s e -l edit -d "Allow code editing"
complete -c ai -n "__fish_seen_subcommand_from code" -l model -d "Override model" -x -a "(_ai_complete_models)"
complete -c ai -n "__fish_seen_subcommand_from code" -l provider -d "Override provider" -x -a "(_ai_providers)"
complete -c ai -n "__fish_seen_subcommand_from code" -l dry-run -d "Show which executor would start"

# --- ai stop ---
complete -c ai -n "__fish_seen_subcommand_from stop" -l server -d "Kill Ollama server entirely"
complete -c ai -n "__fish_seen_subcommand_from stop" -x -a "(ollama ps 2>/dev/null | tail -n +2 | awk '{print \$1}')"

# --- ai chat ---
complete -c ai -n "__fish_seen_subcommand_from chat" -x -a "(_ai_complete_models)"
complete -c ai -n "__fish_seen_subcommand_from chat" -s c -l continue -d "Continue the last chat"
complete -c ai -n "__fish_seen_subcommand_from chat" -s r -l resume -d "Pick a past chat to resume"
complete -c ai -n "__fish_seen_subcommand_from chat" -l model -d "Override model" -x -a "(_ai_complete_models)"
complete -c ai -n "__fish_seen_subcommand_from chat" -l provider -d "Override provider" -x -a "(_ai_providers)"
complete -c ai -n "__fish_seen_subcommand_from chat" -l dry-run -d "Show which executor would start"
