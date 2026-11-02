#!/usr/bin/env fish
# Golden + smoke harness for the `ai` toolkit (phase 0 of docs/refactoring.md).
#
# Every prompt-assembly path runs with --dry-run inside a sandbox: a temporary HOME
# (a controlled ~/.config/ai/config, this repo's prompts, no universal variables) and
# clones of this repo pinned to fixed commits. The output is normalised (ANSI codes,
# sandbox path) and compared byte for byte with tests/ai/golden/<case>.txt. Nothing
# calls a model or the network, and your real config is never read or written.
#
#   tests/ai/run.fish              compare every case
#   tests/ai/run.fish --update     rewrite the goldens (review the git diff afterwards)
#   tests/ai/run.fish NAME...      only these cases

argparse h/help update -- $argv; or exit 2
if set -q _flag_help
    sed -n '2,13p' (status filename) | string replace -r '^# ?' ''
    exit 0
end

set -g root (path resolve (status dirname)/../..)
set -g fn_dir $root/fish/.config/fish/functions
set -g golden_dir $root/tests/ai/golden

# Fixture: master = base_rev, feature = head_rev (checked out). head_rev~1..head_rev is
# one small commit (the gbranch fix); base_rev..head_rev adds a large Brewfile change.
set -g base_rev d6f255b
set -g head_rev 8f00743

set -g sb (path resolve (mktemp -d))
function _harness_cleanup --on-event fish_exit
    rm -rf $sb
end

mkdir -p $sb/home/.config/fish $sb/home/.config/ai $sb/out
ln -s $root/fish/.config/fish/prompts $sb/home/.config/fish/prompts
mkdir -p $sb/home/.agents
ln -s $root/agents/.agents/skills $sb/home/.agents/skills
# model= is shadowed by AI_DEFAULT_MODEL in every case except those that unset it
printf '%s\n' provider=ollama model=config-model review_model=review-model commit_model=commit-model >$sb/home/.config/ai/config
# A HOME with no ai config at all, for "nothing configured" cases
mkdir -p $sb/home-empty

# Installed-model cache (two tags of one model + another model) and model metadata, for
# `ai models`. OLLAMA_HOST points at a dead port (see _harness_run): the cache is all it sees.
mkdir -p $sb/home/.cache
echo '{"models": [
  {"name": "review-model:latest", "digest": "aaaa", "size": 5368709120},
  {"name": "review-model:q4", "digest": "aaaa", "size": 5368709120},
  {"name": "other:7b", "digest": "bbbb", "size": 2147483648}
]}' >$sb/home/.cache/ai-models.json
echo '{"bbbb": {"name": "other:7b", "label": "coding"}}' >$sb/home/.config/ai/models.json
# Architecture per digest (the server is dead, so the cache is the only source)
mkdir -p $sb/home/.cache/ai
echo '{"aaaa": "dense", "bbbb": "MoE 8/64"}' >$sb/home/.cache/ai/model-arch.json
cp $root/tests/ai/fixtures/review.md $sb/review.md
# Extracted comments as a model would return them, for the anchoring case
cp $root/tests/ai/fixtures/comments.json $sb/comments.json
cp $root/tests/ai/fixtures/verify.md $sb/verify.md
cp $root/tests/ai/fixtures/verify-refuted.md $sb/verify-refuted.md
cp $root/tests/ai/fixtures/verify-bare.md $sb/verify-bare.md
cp $root/tests/ai/fixtures/verify-untagged.md $sb/verify-untagged.md
# A stub _ai_run_watched as a function FILE: parallel runs are separate fish processes and
# see only fish_function_path, not functions defined in the parent
cp -R $root/tests/ai/fixtures/stubfn $sb/stubfn

# pi config for the runner paths: ollama, plus a cloud provider on a dead address so the
# reachability probe fails at once (connection refused) and no model is ever called
mkdir -p $sb/home/.pi/agent
echo '{"providers": {
  "ollama":    {"baseUrl": "http://127.0.0.1:11434/v1", "api": "openai-completions", "apiKey": "x",
                "models": [{"id": "review-model"}, {"id": "default-model"}]},
  "testcloud": {"baseUrl": "http://127.0.0.1:9/v1", "api": "openai-completions", "apiKey": "x",
                "models": [{"id": "cloud-model", "contextWindow": 1000, "maxTokens": 500}]}
}}' >$sb/home/.pi/agent/models.json

git clone -q --no-hardlinks $root $sb/fixture; or exit 1
# No remote: git review prefers origin/<base>, which would follow the real repo's master
git -C $sb/fixture remote remove origin
git -C $sb/fixture checkout -q -b feature $head_rev
git -C $sb/fixture branch -q -f master $base_rev

# A second clone with a staged change, for `ai gen commit`
git clone -q --no-hardlinks $root $sb/gen; or exit 1
git -C $sb/gen remote remove origin
git -C $sb/gen checkout -q $head_rev
printf '\nA line added by the ai test harness.\n' >>$sb/gen/README.md
git -C $sb/gen add README.md

# name | dir (fixture, gen) | command run inside the sandbox
set -g golden_cases \
    'git-last-ollama|fixture|ai review --last 1 --dry-run' \
    'git-last-claude|fixture|ai review --last 1 --provider claude --dry-run' \
    'git-commit|fixture|ai review --commit d6f255b --dry-run' \
    'git-commit-range|fixture|ai review --commit 8f00743~2..8f00743 --dry-run' \
    'git-commit-list|fixture|ai review --commit 8f00743,8f00743~1 --dry-run' \
    'git-commit-broken|fixture|ai review --commit 8f00743~3,8f00743 --dry-run; ai review --commit 8f00743..8f00743~2 --dry-run; ai review --commit nosuch --dry-run' \
    'git-comments|fixture|ai review --last 1 --comments -o ../review-out.md --dry-run 2>&1 | string match -e -r "Verify: on|Comments: on|pass 3|comments provider|would write: comments"' \
    'comments-errors|fixture|ai review --last 1 --comments --dry-run; ai review --last 1 --comments --brief -o x.md --dry-run; ai review --last 1 --comments --no-verify -o x.md --dry-run; ai review --last 1 --range a..b; ai review --verify-only ../review.md --range a..b' \
    'git-no-verify|fixture|ai review --last 1 --no-verify --dry-run 2>&1 | string match -q -e "pass 2"; and echo "verify ran"; or echo "no verify pass"' \
    'comments-anchor|fixture|_ai_review_comments_anchor ../comments.json HEAD~1..HEAD (pwd) 3 >../anchored.json; jq -c "(.base_sha | length), (.head_sha | length), .runs, (.comments[] | {path, side, line, line_cited, in_diff, anchored, anchored_by, file_level, seen, status})" ../anchored.json; functions -q _ai_review_comments; _ai_review_comments_md ../anchored.json ../verify.md | string replace -r "Range: \S+" "Range: <range>"; echo "verdicts: "(_ai_verdict_counts ../verify.md)' \
    'review-settings|fixture|mkdir -p .ai; printf "%s\n" review_runs=2 review_runs@testcloud=3 review_runs@testcloud/cloud-model=4 review_parallel@claude=off review_parallel@ollama=on >.ai/config; _ai_review_runs_count testcloud cloud-model ""; _ai_review_runs_count testcloud other ""; _ai_review_runs_count ollama m ""; _ai_review_runs_count ollama m 5; _ai_review_runs_count ollama m abc; _ai_review_parallel_mode claude opus ""; _ai_review_parallel_mode testcloud m ""; _ai_review_parallel_mode ollama m ""; _ai_review_parallel_mode ollama m off; rm -rf .ai' \
    'comments-none|fixture|_ai_review_comments --findings ../review.md --verdicts ../verify-refuted.md --output ../none.md --provider testcloud --range HEAD~1..HEAD --runs 3 --label "[3/3] Comments"; echo "rc: $status"; jq -c "{comments: (.comments | length), runs, base: (.base_sha | length)}" ../none.comments.json; cat ../none.comments.md' \
    'verdicts-bare|fixture|echo "bare: "(_ai_verdict_counts ../verify-bare.md); echo "untagged: "(_ai_verdict_counts ../verify-untagged.md); functions -q _ai_review_comments; _ai_review_comments_md_refuted ../verify-bare.md; echo "== untagged verdicts: the comments stage is not skipped"; _ai_review_comments --findings ../review.md --verdicts ../verify-untagged.md --output ../untagged.md --provider testcloud --range HEAD~1..HEAD --label "[3/3] Comments" 2>&1 | string match -e -r "skipped|Comments" | string replace -r "\| \d+s" "| <t>"; echo "rc: $pipestatus[1]"' \
    'review-runs-redirect|fixture|set -p fish_function_path (realpath ../stubfn); echo prompt >../runs-prompt.txt; function _t; _ai_review_runs --runs 2 --mode $argv[1] --prompt-file ../runs-prompt.txt --output ../runs-joined.md --label "[1/3] Review" -- --provider x; echo "answered: $__ai_review_runs_ok"; end; for m in sequential parallel; echo "== $m"; _t $m >../runs.out 2>../runs.err; echo "stdout:"; cat ../runs.out; echo "stderr:"; string replace -r "\| \d+s" "| <t>" <../runs.err; end; echo "joined:"; cat ../runs-joined.md' \
    'git-runs|fixture|ai review --last 1 --runs 3 -o ../runs-out.md --dry-run 2>&1 | string match -e -r "Verify: on|Runs:|review runs:"; ai review --last 1 --runs 3 --brief --dry-run; ai review --last 1 --runs 3 --no-verify --dry-run; ai review --last 1 --parallel --no-parallel --dry-run; ai review --last 1 --runs 0 --dry-run' \
    'git-branch-auto|fixture|ai review --dry-run' \
    'git-branch-explicit|fixture|ai review master --dry-run' \
    'git-file|fixture|ai review --file Brewfile --dry-run' \
    'git-brief|fixture|ai review --last 1 --brief --dry-run' \
    'git-lens|fixture|ai review --last 1 --lens crypto,logic-bug --dry-run' \
    'git-agentic|fixture|ai review --last 1 --agentic --dry-run' \
    'git-diff-only|fixture|ai review --last 1 --context-lines 0 --dry-run' \
    'git-lang|fixture|ai review --last 1 --lang ru --dry-run' \
    'git-verify|fixture|ai review --last 1 --verify --dry-run' \
    'target-file-ollama|fixture|ai review leetcode/LeetCode.scala --dry-run' \
    'target-file-claude|fixture|ai review leetcode/LeetCode.scala --provider claude --dry-run' \
    'target-dir-ollama|fixture|ai review leetcode --dry-run' \
    'target-dir-claude|fixture|ai review leetcode --provider claude --dry-run' \
    'target-dir-tree-only|fixture|ai review leetcode --context-lines 0 --dry-run' \
    'target-dir-verify|fixture|ai review leetcode --verify --dry-run' \
    'target-context-ollama|fixture|ai review leetcode/LeetCode.scala --with-project-context --dry-run' \
    'target-context-claude|fixture|ai review leetcode/LeetCode.scala --with-project-context --provider claude --dry-run' \
    'target-brief|fixture|ai review leetcode/LeetCode.scala --brief --dry-run' \
    'target-lens|fixture|ai review leetcode/LeetCode.scala --lens access-control --dry-run' \
    'target-agentic|fixture|ai review leetcode/LeetCode.scala --agentic --dry-run' \
    'target-verify|fixture|ai review leetcode/LeetCode.scala --verify --dry-run' \
    'verify-only-ollama|fixture|ai review --verify-only ../review.md --provider ollama --dry-run' \
    'verify-only-range|fixture|ai review --verify-only ../review.md --range HEAD~1..HEAD --provider ollama --dry-run 2>&1 | string match -e -r "^Code: the diff|^Note:|CODE UNDER REVIEW|^diff --git"' \
    'verify-lens|fixture|echo "== verify-only: the lens block in the verify prompt"; ai review --verify-only ../review.md --provider ollama --lens scala --dry-run 2>&1 | string match -e -r "^The review was run with|^## Review lens: |^Scala lens\. |^FINDINGS FROM"; echo "== review + verify: the flow hands the lens on"; ai review --last 1 --verify --lens scala,akka -o ../lens-out.md --dry-run 2>&1 | string match -e -r "^verify provider="; echo "== unknown lens"; ai review --verify-only ../review.md --provider ollama --lens nosuch --dry-run 2>&1 | string match -e -r "unknown lens" | string replace -r "Available: .*" "Available: …"' \
    'verify-only-claude|fixture|ai review --verify-only ../review.md --provider claude --dry-run' \
    'gen-commit-ollama|gen|ai gen commit --dry-run' \
    'gen-commit-claude|gen|ai gen commit --provider claude --dry-run' \
    'gen-summary-ollama|fixture|ai gen summary leetcode --dry-run' \
    'gen-summary-claude|fixture|ai gen summary leetcode --provider claude --dry-run' \
    'run-prompt|fixture|ai --dry-run hello' \
    'run-pipe|fixture|printf "context line\n" | ai --dry-run question' \
    'run-claude|fixture|ai --provider claude --dry-run hello' \
    'run-runner|fixture|ai --provider testcloud --dry-run hello' \
    'run-cloud-runner|fixture|mkdir -p .ai; echo cloud_driver=runner >.ai/config; ai --provider testcloud --dry-run hello; rm -rf .ai' \
    'pi-endpoint|fixture|_ai_agent_pi_endpoint testcloud cloud-model; echo ---; _ai_agent_pi_endpoint testcloud testcloud/cloud-model; echo ---; _ai_agent_pi_endpoint nosuch x; echo "nosuch rc=$status"' \
    'openai-too-big|fixture|string repeat -n 4000 x | _ai_provider_openai --provider testcloud --model cloud-model' \
    'openai-unreachable|fixture|echo hi | _ai_provider_openai --provider testcloud --model cloud-model --no-think' \
    'run-unknown-provider|fixture|ai --provider nosuch --dry-run hello' \
    'run-unreachable|fixture|ai --provider testcloud hello' \
    'config-status|fixture|ai config status' \
    'config-status-model-key|fixture|set -e AI_DEFAULT_MODEL; ai config status' \
    'no-model-configured|fixture|set -e AI_DEFAULT_MODEL; set -gx HOME (path dirname $HOME)/home-empty; ai hello' \
    'ollama-num-ctx|fixture|_ai_ollama_num_ctx 3000; _ai_ollama_num_ctx 600000; echo "ceiling: "(_ai_ollama_max_ctx); set -gx AI_OLLAMA_MAX_CTX 16384; echo "env ceiling: "(_ai_ollama_max_ctx); _ai_ollama_num_ctx 30000' \
    'ollama-host|fixture|set -e OLLAMA_HOST; _ai_ollama_host; set -gx OLLAMA_HOST box:11434; _ai_ollama_host; set -gx OLLAMA_HOST https://ollama.example; _ai_ollama_host' \
    'code-dry|fixture|ai code --dry-run @src; ai code -e --dry-run; ai code --provider claude --dry-run; ai code --provider testcloud --dry-run; ai code --provider nosuch --dry-run' \
    'chat-dry|fixture|ai chat --dry-run; ai chat other:7b --dry-run; ai chat -c --dry-run; ai chat -r --provider claude --dry-run; ai chat --provider testcloud --dry-run' \
    'providers-ls|fixture|ai providers' \
    'providers-check|fixture|ai providers check testcloud; ai providers check ollama; ai providers check nosuch' \
    'models-list|fixture|ai models' \
    'models-filter|fixture|ai models other' \
    'models-provider|fixture|ai models --provider testcloud; echo; ai models --provider claude; echo; ai models --provider nosuch' \
    'models-label-cloud|fixture|ai models label --provider testcloud cloud-model coding; ai models label --provider testcloud nosuch x; ai models --provider testcloud; ai models label --provider testcloud cloud-model general; jq -S . ~/.config/ai/models.json' \
    'config-provider|fixture|ai config provider; ai config provider --task review' \
    'models-label|fixture|ai models label review-model coding; ai models label other:7b general; ai models label nosuch:1b x; jq -S . ~/.config/ai/models.json' \
    'review-prompt-mode|fixture|_ai_review_prompt_mode --origin ollama; _ai_review_prompt_mode --origin claude; _ai_review_prompt_mode --origin testcloud; mkdir -p .ai; echo review_prompt=full >.ai/config; _ai_review_prompt_mode --origin ollama; echo review_prompt=bogus >.ai/config; _ai_review_prompt_mode --origin ollama 2>&1; rm -rf .ai' \
    'model-norm|fixture|_ai_model_norm qwen3; _ai_model_norm qwen3:30b; _ai_model_norm user/model; _ai_model_digest review-model; _ai_model_digest review-model:q4; _ai_model_digest missing; echo "missing rc=$status"' \
    'resolvers|fixture|echo providers: (_ai_providers); echo agents: (_ai_agents); for t in (_ai_tasks); set -l p (_ai_default_provider $t); echo "$t: $p / "(_ai_default_model $t $p); end'

# Help surfaces: must exit 0 and print a usage line
set -g smoke_cases \
    'help-ai|fixture|ai --help' \
    'help-review|fixture|ai review --help' \
    'help-gen|fixture|ai gen --help' \
    'help-config|fixture|ai config --help' \
    'help-models|fixture|ai models --help' \
    'help-code|fixture|ai code --help' \
    'help-chat|fixture|ai chat --help' \
    'help-stop|fixture|ai stop --help'

function _harness_run --argument-names dir cmd
    # stdin from /dev/null: no case may depend on the terminal it was started from
    # AI_NONINTERACTIVE: never ask on /dev/tty (the fallback prompt), even from a terminal
    env -i HOME=$sb/home PATH=(string join : $PATH) TERM=dumb LANG=en_US.UTF-8 AI_DEFAULT_MODEL=default-model \
        AI_NONINTERACTIVE=1 PI_OFFLINE=1 OLLAMA_HOST=127.0.0.1:9 \
        fish --no-config -c "set -p fish_function_path $fn_dir; cd $sb/$dir; and begin; $cmd; end; echo \"[exit \$status]\"" \
        </dev/null 2>&1 \
        | SB=$sb SB_SHORT=(string replace -r '^/private' '' -- $sb) \
            perl -pe 's/\e\[[0-9;?]*[a-zA-Z]//g; s/\Q$ENV{SB}\E/<SANDBOX>/g; s/\Q$ENV{SB_SHORT}\E/<SANDBOX>/g'
end

function _harness_selected --argument-names name
    test (count $argv) -eq 1; and return 0
    contains -- $name $argv[2..]
end

set -l failed
set -l passed 0
set -l updated 0

for c in $golden_cases
    set -l parts (string split -m 2 '|' -- $c)
    _harness_selected $parts[1] $argv; or continue
    set -l out $sb/out/$parts[1].txt
    set -l golden $golden_dir/$parts[1].txt
    _harness_run $parts[2] $parts[3] >$out

    if set -q _flag_update
        mkdir -p $golden_dir
        if not test -f $golden; or not cmp -s $out $golden
            cp $out $golden
            set updated (math $updated + 1)
        end
    else if not test -f $golden
        echo "FAIL $parts[1]: no golden (run with --update)"
        set -a failed $parts[1]
    else if cmp -s $out $golden
        set passed (math $passed + 1)
    else
        echo "FAIL $parts[1]:"
        diff -u $golden $out | sed 's/^/  /' | head -40
        set -a failed $parts[1]
    end
end

for c in $smoke_cases
    set -l parts (string split -m 2 '|' -- $c)
    _harness_selected $parts[1] $argv; or continue
    set -l output (_harness_run $parts[2] $parts[3])
    if string match -q '[exit 0]' -- $output[-1]; and string match -qi '*usage*' -- $output
        set passed (math $passed + 1)
    else
        echo "FAIL $parts[1]: "(string join ' ' -- $output[-3..-1])
        set -a failed $parts[1]
    end
end

# Goldens without a case are leftovers from renamed or removed cases
if test (count $argv) -eq 0; and test -d $golden_dir
    for g in $golden_dir/*.txt
        set -l name (path change-extension '' (path basename $g))
        if not string match -q "$name|*" -- $golden_cases
            echo "WARN stale golden: $name"
        end
    end
end

if set -q _flag_update
    echo "updated $updated golden(s); smoke: $passed passed"
end
if test (count $failed) -gt 0
    echo (count $failed)" failed, $passed passed"
    exit 1
end
set -q _flag_update; or echo "all $passed passed"
