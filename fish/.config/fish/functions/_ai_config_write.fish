function _ai_config_write --description "Write KEY=VALUE to global ~/.config/ai/config" --argument-names key value
    _ai_config_write_file ~/.config/ai/config $key $value
end
