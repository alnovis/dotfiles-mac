function _ai_config_remove --description "Remove KEY from global ~/.config/ai/config" --argument-names key
    _ai_config_remove_file ~/.config/ai/config $key
end
