if status is-interactive
    # Приветствие
    set -g fish_greeting ""

    # Навигация
    alias ..="cd .."
    alias ...="cd ../.."
    alias ll="ls -la"
    alias la="ls -A"

    # Git алиасы
    alias g="git"
    alias gs="git st"
    alias gl="git lg"
    alias gp="git push"
    alias gpl="git pull"
    alias gc="git commit"
    alias gca="git commit --amend --no-edit"
    alias gco="git checkout"
    alias gb="git branch"
    alias gd="git diff"
    alias ga="git add"
    alias gaa="git add -A"
    alias lg="lazygit"

    # Dev
    alias v="nvim"
    alias vi="nvim"
    alias vim="nvim"
    alias idea="open -a 'IntelliJ IDEA CE'"
    alias rr="open -a RustRover"

    # Docker (OrbStack)
    alias d="docker"
    alias dc="docker compose"
    alias dps="docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

    # Быстрые директории
    alias work="cd ~/work"

    # Ollama
    alias ai="ollama serve & sleep 2; and ollama run deepseek-coder-v2:16b"
    alias ai-chat="ollama serve & sleep 2; and ollama run llama3.1:8b"
    alias ai-stop="pkill ollama"
end

# PATH
fish_add_path ~/.cargo/bin
fish_add_path ~/.local/share/coursier/bin
fish_add_path "/Users/alnovis/Library/Application Support/Coursier/bin"

# SDKMAN (Java)
set -gx JAVA_HOME (string replace -r '/bin/java$' '' (which java 2>/dev/null); or echo "")

# OrbStack
source ~/.orbstack/shell/init2.fish 2>/dev/null || :

# Bat
#set -x PAGER 'bat --plain'
#alias less 'bat --plain'
set -x PAGER bat
alias less bat
