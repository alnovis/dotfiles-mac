function _ai_no_tools_prompt --description "System prompt for a runner's tools=none profile"
    # A coding agent's default system prompt describes its tools even when they are all
    # disabled, and a model may answer a big prompt with "I'll examine the files…" and stop.
    echo "You are a careful senior engineer. You have NO tools in this conversation: you cannot open files, search, or run commands, and none will be offered. Everything you need is in the user's message. Answer directly and completely in this single reply."
end
