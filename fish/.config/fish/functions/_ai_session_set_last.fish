function _ai_session_set_last --description "Write NAME as .last pointer in the dir of the session FILE" --argument-names file name
    if test -z "$file"; or test -z "$name"
        return 1
    end
    set -l dir (dirname $file)
    mkdir -p $dir
    echo $name >$dir/.last
end
