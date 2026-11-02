function _ai_ui_duration --description "Seconds as 45s, 11m 47s or 1h 02m" --argument-names secs
    if test $secs -lt 60
        echo $secs"s"
    else if test $secs -lt 3600
        printf '%dm %02ds\n' (math "floor($secs / 60)") (math "$secs % 60")
    else
        printf '%dh %02dm\n' (math "floor($secs / 3600)") (math "floor($secs % 3600 / 60)")
    end
end
