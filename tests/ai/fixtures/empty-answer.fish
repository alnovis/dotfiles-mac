# _ai_run_watched on an agentic run that answers nothing, a tool call as text, or a leaked
# answer, or one ai-guard aborted — against a stand-in _ai_run: it writes the usage JSON the
# pi runner would, prints the answer file it is given, and the runner's stderr. Sourced by the harness (empty-answer).
function _ai_run
    set -l i (contains -i -- --usage-output $argv)
    printf '%s\n' $__t_usage >$argv[(math $i + 1)]
    test -n "$__t_answer"; and cat $__t_answer
    set -q __t_stderr[1]; and printf '%s\n' $__t_stderr >&2
    return 0
end

function __t_case -a title usage answer
    set -g __t_usage $usage
    set -g __t_answer $answer
    set -g __t_stderr $argv[4..]
    echo "== $title"
    echo prompt | _ai_run_watched --label "Review - testcloud - m" --row "run 1/1" --output ../ea.md --dest ../ea.md -- --provider testcloud --agentic 2>&1 \
        | string replace -r '\b[0-9]+s  ' 'Ns  '
    echo "status $pipestatus[2]; why: $__ai_last_failure"
end

set -l stats '"prompt_tokens": 9000, "completion_tokens": 32768, "completion_tokens_details": {"reasoning_tokens": 32000}'
__t_case "max_tokens reached" "{$stats, \"agent\": {\"turns\": 2, \"tool_calls\": 1, \"tools\": [], \"last_stop\": \"length\", \"last_output\": 32768, \"last_reasoning\": 32000}}" ""
__t_case "an empty last turn" '{"prompt_tokens": 9000, "completion_tokens": 10, "agent": {"turns": 1, "tool_calls": 0, "tools": [], "last_stop": "stop", "last_output": 10, "last_reasoning": 0}}' ""
__t_case "a tool call as text" '{"prompt_tokens": 9000, "completion_tokens": 90, "agent": {"turns": 12, "tool_calls": 11, "tools": [], "last_stop": "stop", "last_output": 90, "last_reasoning": 0}}' ../answers/action.md
__t_case "an answer with no tool calls" '{"prompt_tokens": 8100, "completion_tokens": 1700, "agent": {"turns": 1, "tool_calls": 0, "tools": [], "last_stop": "stop", "last_output": 1700, "last_reasoning": 0}}' ../answers/plain.md
__t_case "aborted by ai-guard" '{"prompt_tokens": 187000, "completion_tokens": 19300, "agent": {"turns": 17, "tool_calls": 17, "tools": [], "last_stop": "toolUse", "last_output": 900, "last_reasoning": 0}}' "" \
    "ai-guard: the time budget (900s) is spent at 900s: tools off, the model is told to answer" \
    "ai-guard: aborted at 1080s: no answer 180s after the time budget (900s)"
__t_case "a leaked answer, cleaned" '{"prompt_tokens": 9000, "completion_tokens": 900, "agent": {"turns": 3, "tool_calls": 2, "tools": [], "last_stop": "stop", "last_output": 900, "last_reasoning": 0}}' ../answers/leak.md
echo "== the saved answer"
string match -v -r '^Run: ' <../ea.md
