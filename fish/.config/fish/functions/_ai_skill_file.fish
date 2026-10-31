function _ai_skill_file --description "Path of the installed SKILL.md for skill NAME (ai-review, ai-verify); fails if not installed" --argument-names name
    # Skills ship in the dotfiles `agents` stow package and are installed into
    # ~/.agents/skills (docs/refactoring.md §6a). Our runs inject the file explicitly instead of
    # relying on a runner deciding to load it.
    set -l f ~/.agents/skills/$name/SKILL.md
    test -f $f; or return 1
    echo $f
end
