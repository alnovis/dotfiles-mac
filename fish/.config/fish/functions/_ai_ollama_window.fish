function _ai_ollama_window --description "The window to send MODEL a prompt that needs NUM_CTX: the loaded one when big enough, else the model loaded again with NUM_CTX; prints the window (nothing when unknown), fails when the model does not load" --argument-names model num_ctx
    # A loaded model keeps its window: ollama (0.40, mlx runner) runs a request with another
    # num_ctx in the window the model was loaded with, without a word. A prompt longer than it
    # is read whole, minutes of silence, and the answer is empty (done_reason "length"): a
    # 121k-token review sent after a verify had loaded the model at 73728 timed out with no
    # data. So a window smaller than needed is unloaded first and the model loaded with
    # NUM_CTX; a bigger one is used as it is (the window only grows: no load between the
    # stages of one review, and the prompt cache stays).
    set -l host (_ai_ollama_host)
    # A bare name is the :latest tag, as /api/ps lists it
    set -l name $model
    string match -q '*:*' -- $name; or set name $name:latest
    set -l ps_window '[.models[]? | select(.name == $m or .model == $m) | .context_length][0] // empty'
    set -l loaded (curl -sS --connect-timeout 10 --max-time 10 $host/api/ps 2>/dev/null | jq -r --arg m $name $ps_window 2>/dev/null)
    if string match -qr '^[0-9]+$' -- "$loaded"
        if test $loaded -ge $num_ctx
            echo $loaded
            return 0
        end
        echo "ollama: $model is loaded with a $loaded-token window, $num_ctx needed: loading it again" >&2
    end
    # keep_alive 0 unloads the model (once its runner is free: it waits for a request in work);
    # an empty prompt then loads it with the asked window
    set -l load_timeout 180
    set -l rc 0
    if test -n "$loaded"
        jq -cn --arg m $model '{model:$m, prompt:"", stream:false, keep_alive:0}' \
            | curl -sS --connect-timeout 10 --max-time $load_timeout $host/api/generate -d @- >/dev/null 2>&1
        set rc $pipestatus[2]
    end
    if test $rc -eq 0
        jq -cn --arg m $model --argjson ctx $num_ctx '{model:$m, prompt:"", stream:false, options:{num_ctx:$ctx}}' \
            | curl -sS --connect-timeout 10 --max-time $load_timeout $host/api/generate -d @- >/dev/null 2>&1
        set rc $pipestatus[2]
    end
    if test $rc -eq 28
        echo "ollama: $model did not load in $load_timeout s: its runner is still busy with another request (ollama ps)" >&2
        return 1
    else if test $rc -ne 0
        echo "ollama: loading $model failed (curl exit $rc)" >&2
        return 1
    end
    curl -sS --connect-timeout 10 --max-time 10 $host/api/ps 2>/dev/null | jq -r --arg m $name $ps_window 2>/dev/null
    return 0
end
