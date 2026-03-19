function _ai_lang_name --argument-names code
    if test -z "$code"
        return
    end

    switch (string lower $code)
        case en; echo "English"
        case ru; echo "Russian"
        case fr; echo "French"
        case de; echo "German"
        case es; echo "Spanish"
        case pl; echo "Polish"
        case pt; echo "Portuguese"
        case it; echo "Italian"
        case nl; echo "Dutch"
        case ja; echo "Japanese"
        case ko; echo "Korean"
        case zh; echo "Chinese"
        case tr; echo "Turkish"
        case ar; echo "Arabic"
        case uk; echo "Ukrainian"
        case cs; echo "Czech"
        case sv; echo "Swedish"
        case '*'
            echo $code
    end
end
