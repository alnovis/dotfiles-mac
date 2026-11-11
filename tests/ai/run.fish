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
# The pi extension of unattended runs, and a repository for its path checks: a file inside,
# a symlink that leads out
ln -s $root/fish/.config/fish/pi $sb/home/.config/fish/pi
cp $root/tests/ai/pi-guard.test.mjs $sb/pi-guard.test.mjs
mkdir -p $sb/guard-repo/src $sb/guard-elsewhere
touch $sb/guard-repo/src/a.scala
ln -s $sb/guard-elsewhere $sb/guard-repo/link-out
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
cp $root/tests/ai/fixtures/review-shapes.md $root/tests/ai/fixtures/review-shapes-translated.md $sb/
cp $root/tests/ai/fixtures/review-context.md $sb/review-context.md
# Outcome marks as a person fills them in, and the ones a person can get wrong
cp $root/tests/ai/fixtures/lessons-marks.awk $root/tests/ai/fixtures/lessons-bad.awk $sb/
# A pi session file (JSONL) of an agentic run, for the usage stats in the footer
cp $root/tests/ai/fixtures/pi-session.jsonl $sb/pi-session.jsonl
# A runner's stderr: a gateway's HTML 503 page, a run line coloured without a terminal,
# and a failed run whose stats hold a cost like 3.516 (not an HTTP status)
cp $root/tests/ai/fixtures/runner-503.txt $sb/runner-503.txt
cp $root/tests/ai/fixtures/runner-colored.txt $sb/runner-colored.txt
cp $root/tests/ai/fixtures/runner-stats.txt $sb/runner-stats.txt
# Three verify runs over one review, for the majority vote
cp -R $root/tests/ai/fixtures/vote $sb/vote
cp $root/tests/ai/fixtures/verify-untagged.md $sb/verify-untagged.md
# Agentic answers: a leak of control tokens, a tool call as text (two shapes), a plain one;
# a verify run whose verdicts carry no finding numbers; the empty-answer cases
cp -R $root/tests/ai/fixtures/answers $sb/answers
cp $root/tests/ai/fixtures/verify-unkeyed.md $sb/verify-unkeyed.md
cp $root/tests/ai/fixtures/empty-answer.fish $sb/empty-answer.fish
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
    'git-prompt-place|fixture|echo "== --last with a lone text: the custom prompt"; ai review --last 1 focus --dry-run 2>&1 | string match -e -r "Additional instructions"; echo "== a text where the base goes"; ai review focus --dry-run; echo "== the diff cut: said in the prompt"; ai review --last 1 --max-lines 5 --dry-run 2>&1 | string match -e -r "^Diff"' \
    'review-fence|fixture|echo "== the fence takes the file name extension, not the path"; mkdir -p ../fx/.config/x; echo hi >../fx/.config/x/LICENSE; echo hi >../fx/.config/x/a.toml; _ai_review_files_block ../fx .config/x/LICENSE .config/x/a.toml | string match -e -r "^```"' \
    'config-walk-worktree|fixture|mkdir -p ../wk/.ai ../wk/sub; echo review_lens=crypto >../wk/.ai/config; echo "gitdir: /elsewhere" >../wk/sub/.git; cd ../wk/sub; echo "[$(_ai_project_config_file)]"; cd ..; echo "[$(_ai_project_config_file | string replace -r ".*/wk/" "wk/")]"' \
    'git-last-claude|fixture|ai review --last 1 --provider claude --dry-run' \
    'git-commit|fixture|ai review --commit d6f255b --dry-run' \
    'git-commit-range|fixture|ai review --commit 8f00743~2..8f00743 --dry-run' \
    'git-commit-list|fixture|ai review --commit 8f00743,8f00743~1 --dry-run' \
    'git-commit-broken|fixture|ai review --commit 8f00743~3,8f00743 --dry-run; ai review --commit 8f00743..8f00743~2 --dry-run; ai review --commit nosuch --dry-run' \
    'git-comments|fixture|ai review --last 1 --comments -o ../review-out.md --dry-run 2>&1 | string match -e -r "^  verify +on|^  comments +on|pass 3|comments provider|would write: comments"' \
    'comments-errors|fixture|ai review --last 1 --comments --dry-run; ai review --last 1 --comments --brief -o x.md --dry-run; ai review --last 1 --comments --no-verify -o x.md --dry-run; ai review --last 1 --range a..b; ai review --verify-only ../review.md --range a..b' \
    'git-no-verify|fixture|ai review --last 1 --no-verify --dry-run 2>&1 | string match -q -e "pass 2"; and echo "verify ran"; or echo "no verify pass"' \
    'comments-anchor|fixture|_ai_review_comments_anchor ../comments.json HEAD~1..HEAD (pwd) 3 >../anchored.json; jq -c "(.base_sha | length), (.head_sha | length), .runs, (.comments[] | {findings, path, side, line, line_cited, in_diff, anchored, anchored_by, file_level, seen, status})" ../anchored.json; functions -q _ai_review_comments; _ai_review_comments_md ../anchored.json ../verify.md | string replace -r "Range: \S+" "Range: <range>"; echo "verdicts: "(_ai_verdict_counts ../verify.md)' \
    'review-settings|fixture|mkdir -p .ai; printf "%s\n" review_runs=2 review_runs@testcloud=3 review_runs@testcloud/cloud-model=4 review_parallel@claude=off review_parallel@ollama=on >.ai/config; _ai_review_runs_count testcloud cloud-model ""; _ai_review_runs_count testcloud other ""; _ai_review_runs_count ollama m ""; _ai_review_runs_count ollama m 5; _ai_review_runs_count ollama m abc; _ai_review_parallel_mode claude opus ""; _ai_review_parallel_mode testcloud m ""; _ai_review_parallel_mode ollama m ""; _ai_review_parallel_mode ollama m off; rm -rf .ai' \
    'comments-none|fixture|_ai_review_comments --findings ../review.md --verdicts ../verify-refuted.md --output ../none.md --provider testcloud --range HEAD~1..HEAD --runs 3 --label "[3/3] Comments"; echo "rc: $status"; jq -c "{comments: (.comments | length), runs, base: (.base_sha | length)}" ../none.comments.json; cat ../none.comments.md' \
    'verdicts-bare|fixture|echo "bare: "(_ai_verdict_counts ../verify-bare.md); echo "untagged: "(_ai_verdict_counts ../verify-untagged.md); functions -q _ai_review_comments; _ai_review_comments_md_refuted ../verify-bare.md; echo "== untagged verdicts: the comments stage is not skipped"; _ai_review_comments --findings ../review.md --verdicts ../verify-untagged.md --output ../untagged.md --provider testcloud --range HEAD~1..HEAD --label "[3/3] Comments" 2>&1 | string match -e -r "skipped|Comments|FAILED" | string replace -r "FAILED +\d+s" "FAILED <t>"; echo "rc: $pipestatus[1]"' \
    'review-runs-redirect|fixture|set -p fish_function_path (realpath ../stubfn); echo prompt >../runs-prompt.txt; function _t; _ai_review_runs --runs 2 --mode $argv[1] --prompt-file ../runs-prompt.txt --output ../runs-joined.md --label "[1/3] Review" -- --provider x; echo "answered: $__ai_review_runs_ok"; end; for m in sequential parallel; echo "== $m"; _t $m >../runs.out 2>../runs.err; echo "stdout:"; cat ../runs.out; echo "stderr:"; string replace -r "answered, \d+s" "answered, <t>" <../runs.err; end; echo "joined:"; cat ../runs-joined.md' \
    'review-runs-failed|fixture|set -p fish_function_path (realpath ../stubfn); set -gx AI_STUB_FAIL 2; echo prompt >../runs-prompt.txt; for m in sequential parallel; echo "== $m"; _ai_review_runs --runs 3 --mode $m --prompt-file ../runs-prompt.txt --output ../runs-joined.md --label "[2/3] Verify" -- --provider x 2>/dev/null; echo "rc $status, answered: $__ai_review_runs_ok"; printf "failed: %s\n" $__ai_runs_failed; end; set -e AI_STUB_FAIL; echo "== summary"; _ai_runs_failed_lines "run 2/3: truncated" "run 3/3: 429" | string replace -a -r "\e\[[0-9;]*m" ""; true' \
    'git-runs|fixture|ai review --last 1 --runs 3 -o ../runs-out.md --dry-run 2>&1 | string match -e -r "^  verify +on|^  runs |review runs:"; ai review --last 1 --runs 3 --brief --dry-run; ai review --last 1 --runs 3 --no-verify --dry-run; ai review --last 1 --parallel --no-parallel --dry-run; ai review --last 1 --runs 0 --dry-run' \
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
    'verify-only-range|fixture|ai review --verify-only ../review.md --range HEAD~1..HEAD --provider ollama --dry-run 2>&1 | string match -e -r "^  code +the diff|^  note |CODE UNDER REVIEW|^diff --git"' \
    'verify-vote|fixture|_ai_verify_vote 3 ../vote/verify.run1.md ../vote/verify.run2.md ../vote/verify.run3.md >../voted.md; cat ../voted.md; echo "== counts: "(_ai_verdict_counts ../voted.md); functions -q _ai_review_comments; _ai_review_comments_md_refuted ../voted.md; echo "== one run of three answered: everything uncertain"; _ai_verify_vote 3 ../vote/verify.run1.md | string match -e -r "^- |^Verify:"; echo "== run 2 failed: its column stays empty"; _ai_verify_vote 3 ../vote/verify.run1.md ../vote/verify.run3.md | string match -e "votes:"; echo "== an [Fn] in a why: line is a mention, a verdict without a bullet counts"; mkdir -p ../vote2; printf "%s\n" "- [F1] lost update - [CONFIRMED 7/10]" "  why: unlike [F2], this one is real." "[F2] reversed - REFUTED 8/10" "  why: no bullet." >../vote2/v.run1.md; cp ../vote2/v.run1.md ../vote2/v.run2.md; _ai_verify_vote 2 ../vote2/v.run1.md ../vote2/v.run2.md | string match -e -r "^- |why:|^Verify:"' \
    'verify-runs|fixture|echo "== review + verify"; ai review --last 1 --verify-runs 3 -o ../vr-out.md --dry-run 2>&1 | string match -e -r "^  verify +on|^verify runs:"; echo "== verify-only"; ai review --verify-only ../review.md --provider ollama --verify-runs 3 --dry-run 2>&1 | string match -e -r "^  runs "; echo "== bad value"; ai review --verify-only ../review.md --provider ollama --verify-runs 0 --dry-run; echo "== config"; mkdir -p .ai; cp .ai/config ../cfg2.bak 2>/dev/null; or rm -f ../cfg2.bak; echo verify_runs@ollama=3 >.ai/config; ai config status 2>&1 | string match -e -r "^ +verify runs"; rm -f .ai/config; test -f ../cfg2.bak; and mv ../cfg2.bak .ai/config' \
    'verify-provider-header|fixture|mkdir -p .ai; cp .ai/config ../cfg3.bak 2>/dev/null; or rm -f ../cfg3.bak; echo verify_provider=claude >.ai/config; echo "== git mode: from the config"; ai review --last 1 --verify --dry-run 2>&1 | string match -e -r "^  verify +on|^verify provider="; echo "== target mode"; ai review leetcode/LeetCode.scala --verify --dry-run 2>&1 | string match -e -r "^  verify +on"; echo "== the flag wins"; ai review --last 1 --verify --verify-provider ollama --dry-run 2>&1 | string match -e -r "^  verify +on|^verify provider="; rm -f .ai/config; test -f ../cfg3.bak; and mv ../cfg3.bak .ai/config' \
    'comments-lang|fixture|set -l re "^  comments |^  language |^comments language:|^IMPORTANT: Write"; echo "== git mode: review in English, comments in Russian"; ai review --last 1 --comments-lang ru -o ../cl.md --dry-run 2>&1 | string match -e -r $re; echo "== target mode"; ai review leetcode/LeetCode.scala --comments-lang ru -o ../cl.md --dry-run 2>&1 | string match -e -r $re; echo "== --lang alone: the comments follow it"; ai review --last 1 --lang de --comments -o ../cl.md --dry-run 2>&1 | string match -e -r $re; echo "== verify-only with verdicts"; ai review --verify-only ../review.md --verdicts ../verify.md --comments-lang ru --provider ollama --range HEAD~1..HEAD --dry-run 2>&1 | string match -e -r $re; echo "== needs -o"; ai review --last 1 --comments-lang ru --dry-run' \
    'failed-stdout|fixture|function _ai_run; cat >/dev/null; if set -q __ai_t_review_done; printf "API Error: Opus 5.5\x27s safeguards flagged this message (https://www.anthropic.com/legal/aup). This sometimes happens.\n\nRequest ID: req_x\n"; return 1; end; printf "## Important issues\n\n- [F1] **a bug** - ghwatch.fish:3\n"; end; echo "== one run: the error is the reason, the file stays empty"; set -g __ai_t_review_done 1; echo prompt | _ai_run_watched --label "[2/3] Verify - claude" --output ../fs.md -- --provider claude 2>&1 | string replace -r "FAILED +[0-9]+s" "FAILED <t>"; echo "file bytes: "(wc -c <../fs.md | string trim); set -e __ai_t_review_done; echo "== review, then verify fails: no comments from it"; function _ai_review_verify; set -g __ai_t_review_done 1; argparse -i "output=" -- $argv; _ai_run_watched --label "[2/3] Verify - claude" --output $_flag_output -- --provider claude </dev/null; end; ai review --last 1 --provider claude --comments -o ../fs-review.md 2>&1 | string replace -ra "\e\[[0-9;]*m" "" | string match -e -r "^  (?:verify|comments) |FAILED" | string replace -r "FAILED +[0-9]+s" "FAILED <t>"; test -e ../fs-review.verify.md; and echo "verify file left behind"; or echo "no verify file"' \
    'verdicts-no-model|fixture|echo "== claude, no model: the label keeps its value"; ai review --verify-only ../review.md --verdicts ../verify.md --provider claude --comments --range HEAD~1..HEAD --dry-run 2>&1 | string match -e -r "requires|^comments provider="; echo "== no range: the line is still there"; ai review --verify-only ../review.md --verdicts ../verify.md --provider claude --comments --dry-run 2>&1 | string match -e -r "requires|^comments provider="' \
    'review-numbering|fixture|_ai_review_number_findings <../review-shapes.md >../shapes-1.md; cat ../shapes-1.md; echo "== numbering twice changes nothing"; _ai_review_number_findings <../shapes-1.md | diff -q - ../shapes-1.md; and echo same; echo "== headings with no Latin word: each is a section, its bullets numbered"; _ai_review_number_findings <../review-shapes-translated.md' \
    'answer-clean|fixture|for f in leak action json-calls plain; cp ../answers/$f.md ../ac-$f.md; _ai_answer_clean ../ac-$f.md; echo "== $f: status $status"; cat ../ac-$f.md; end; cmp -s ../ac-plain.md ../answers/plain.md; and echo "plain: byte for byte"' \
    'verify-keyed|fixture|echo "keyed run: "(_ai_verify_keyed ../vote/verify.run1.md); echo "unkeyed run: "(_ai_verify_keyed ../verify-unkeyed.md); _ai_verify_runs_note 3 ../vote/verify.run1.md ../verify-unkeyed.md; _ai_verify_runs_note 3 ../vote/verify.run1.md ../vote/verify.run2.md' \
    'empty-answer|fixture|source ../empty-answer.fish' \
    'progress-line|fixture|mkdir -p ../ps; cp ../pi-session.jsonl ../ps/s.jsonl; echo -n "session: "; _ai_session_progress ../ps | cut -f1,2,4,5,6,7 | tr \t "|"; touch -t 202601010000 ../ps/s.jsonl; echo 12345 >../ps/pulse; set -l p (_ai_session_progress ../ps | string split \t); echo "streaming: idle by the "(test $p[3] -lt 60; and echo pulse; or echo session)", $p[7] chars"; _ai_progress_line "run 2/3  " 102 100 3 "read RouteStage.scala" 12 ollama/qwen3.8:27b 57300 model "" 131072; echo; _ai_progress_line "" 702 100 7 "grep isWelcomeDone" 410 ollama/qwen3.8:27b 64000 "tool grep isWelcomeDone" "" 131072; echo; _ai_progress_line "" 45 80; echo; _ai_progress_line "run 1/3  " 100 60 12 "read a/very/long/path/that/does/not/fit/anywhere.scala" 0 testcloud/m 1200000 model "" ""; echo; _ai_progress_line "" 400 100 5 "read Graph.scala" 0 ollama/granite4.2:8b 30000 model 12345 131072; echo' \
    'pi-guard|fixture|node ../pi-guard.test.mjs ~/.config/fish/pi/ai-guard.ts ../guard-repo' \
    'runner-errors|fixture|echo "== a 503 page"; _ai_runner_errors <../runner-503.txt; echo "reason: "(_ai_failure_reason <../runner-503.txt); echo "== a coloured run line"; echo "reason: "(_ai_failure_reason <../runner-colored.txt); echo "== a cost in the stats is no status"; echo "reason: "(_ai_failure_reason <../runner-stats.txt)' \
    'verify-only-numbers|fixture|cp ../review-shapes.md ../vo.md; ai review --verify-only ../vo.md --provider testcloud >/dev/null 2>&1; echo "numbered in the review file: "(grep -c "\[F[0-9]" ../vo.md); cp ../vo.md ../vo-1.md; ai review --verify-only ../vo.md --provider testcloud >/dev/null 2>&1; cmp -s ../vo.md ../vo-1.md; and echo "a re-verify leaves the numbers as they are"; echo "== dry-run writes nothing"; cp ../review-shapes.md ../vo-dry.md; ai review --verify-only ../vo-dry.md --provider ollama --dry-run >/dev/null 2>&1; cmp -s ../vo-dry.md ../review-shapes.md; and echo unchanged' \
    'pi-session-stats|fixture|_ai_pi_session_stats ../pi-session.jsonl; echo "== no model answer: nothing"; head -3 ../pi-session.jsonl >../pi-empty.jsonl; _ai_pi_session_stats ../pi-empty.jsonl; echo "rc $status"; echo "== the footer of an agentic run"; function _ai_run; argparse -i "usage-output=" -- $argv; _ai_pi_session_stats ../pi-session.jsonl >$_flag_usage_output; echo answer; end; echo prompt | _ai_run_watched --label "[1/3] Review" --output ../pi-footer.md -- --agentic --provider x 2>../pi-footer.err; string replace -r "done +[0-9]+s" "done <t>" <../pi-footer.err; string replace -r " \\| [0-9]+s \\| " " | Ns | " <../pi-footer.md; echo "== no usage: the estimate"; function _ai_run; echo answer; end; echo prompt | _ai_run_watched --heading --label "[1/1] Review - testcloud - cloud-model" --output ../est-footer.md -- --agentic --provider x 2>&1 | string replace -r "done +[0-9]+s" "done <t>"; string replace -r " \\| [0-9]+s \\| " " | Ns | " <../est-footer.md' \
    'lens-default|fixture|mkdir -p .ai; cp .ai/config ../cfg.bak 2>/dev/null; or rm -f ../cfg.bak; echo review_lens=scala >.ai/config; echo "== from the project config"; ai review --last 1 --dry-run 2>&1 | string match -e -r "^  lens |^## Review lens: "; echo "== --lens wins"; ai review --last 1 --lens redis --dry-run 2>&1 | string match -e -r "^  lens |^## Review lens: "; echo "== --no-lens: none"; ai review --last 1 --no-lens --dry-run 2>&1 | string match -e -r "^  lens |^## Review lens: "; or echo "(no lens)"; echo "== both"; ai review --last 1 --lens redis --no-lens --dry-run; echo "== verify-only takes the default"; ai review --verify-only ../review.md --provider ollama --dry-run 2>&1 | string match -e -r "^## Review lens: "; echo "== config status"; ai config status 2>&1 | string match -e -r "^ +lens "; rm -f .ai/config; test -f ../cfg.bak; and mv ../cfg.bak .ai/config' \
    'verify-lens|fixture|echo "== verify-only: the lens block in the verify prompt"; ai review --verify-only ../review.md --provider ollama --lens scala --dry-run 2>&1 | string match -e -r "^The review was run with|^## Review lens: |^Scala lens\. |^FINDINGS FROM"; echo "== review + verify: the flow hands the lens on"; ai review --last 1 --verify --lens scala,akka -o ../lens-out.md --dry-run 2>&1 | string match -e -r "^verify provider="; echo "== unknown lens"; ai review --verify-only ../review.md --provider ollama --lens nosuch --dry-run 2>&1 | string match -e -r "unknown lens" | string replace -r "Available: .*" "Available: …"' \
    'verify-only-claude|fixture|ai review --verify-only ../review.md --provider claude --dry-run' \
    'verify-context|fixture|git diff HEAD~1..HEAD >../ctx.diff; echo "== window 3"; _ai_verify_context --window 3 --diff ../ctx.diff ../review-context.md .; echo "== budget 20: what is left out"; _ai_verify_context --window 3 --budget 20 --diff ../ctx.diff ../review-context.md . | string match -v -r "^ +[0-9]+  "; echo "== a nit under a bold heading is not code for the finding above"; printf "## Important issues\n\n- [F1] wrong order at fish/.config/fish/functions/gbranch.fish:3\n\n**Nits**\n\n- a typo at fish/.config/fish/functions/gbranch.fish:30\n" >../ctx-nits.md; _ai_verify_context --window 1 ../ctx-nits.md .' \
    'verify-context-flags|fixture|echo "== verify-only"; ai review --verify-only ../review-context.md --range HEAD~1..HEAD --provider ollama --verify-context assembled --dry-run 2>&1 | string match -e -r "^  context |^CODE FOR THE|^### |^Not found|^Cite no|^You have no tools|^--- dry-run"; echo "== --agentic gives no tools"; ai review --verify-only ../review-context.md --range HEAD~1..HEAD --provider claude --agentic --verify-context assembled --dry-run 2>&1 | string match -e -r "^--- dry-run|tools|skill"; echo "== no diff"; ai review --verify-only ../review-context.md --provider ollama --verify-context assembled --dry-run 2>&1 | string match -e -r "^  note |^  +cannot"; echo "== review + verify"; ai review --last 1 --verify-context assembled -o ../vc-out.md --dry-run 2>&1 | string match -e -r "^verify provider="; echo "== bad value"; ai review --last 1 --verify-context agentic --dry-run' \
    'think-level|fixture|function ollama; printf "  Capabilities\n    completion\n"; test "$argv[2]" = plain; or printf "    thinking\n        levels     false, low, medium, xhigh    \n"; end; function _ai_ensure_running; end; function curl; cat >../tl-req.json; echo "{\"response\":\"ok\",\"done\":true}"; end; for a in "--think-level low" "--think-level false" "--no-think --think-level medium" "--no-think" "" "--think-level high" "--model plain --think-level low"; echo "== $a"; rm -f ../tl-req.json; echo hi | _ai_provider_ollama --model m (string split -n " " -- $a) >/dev/null 2>../tl.err; set -l rc $status; echo "rc $rc, think: "(test -f ../tl-req.json; and jq -c .think ../tl-req.json; or echo "no request"); string match -v -e num_ctx <../tl.err; end; echo "== a runner, claude"; ai --provider testcloud --think-level low --dry-run hello 2>&1 | string match -e -- "think-level"; ai --provider claude --think-level low --dry-run hello 2>&1 | string match -e -- "think-level"' \
    'verify-think|fixture|function _ai_run; cat >/dev/null; echo "runner gets:" (string match -r -a -- "--no-think|--think-level \S+" (string join " " -- $argv)); end; function _t; ai review --verify-only ../review-context.md --provider ollama --dry-run $argv 2>&1 | string match -e -r "^  think |^runner gets"; end; for a in "--verify-think low" "--no-think" "--no-think --verify-think low" ""; echo "== $a"; _t (string split -n " " -- $a); end; mkdir -p .ai; echo verify_think=low >.ai/config; echo "== config verify_think=low"; _t; echo "== config, --no-think"; _t --no-think; echo "== config, review + verify"; ai review --last 1 --verify -o ../vt-out.md --dry-run 2>&1 | string match -e -r "^verify provider="; rm -rf .ai; echo "== bad value"; ai review --last 1 --verify-think lots --dry-run' \
    'claude-isolation|fixture|function claude; cat >/dev/null; echo "args: $argv"; echo "memory off: $CLAUDE_CODE_DISABLE_AUTO_MEMORY, CLAUDE.md off: $CLAUDE_CODE_DISABLE_CLAUDE_MDS"; end; echo "== a review run"; echo hi | _ai_agent_claude --tools read --no-session; echo "== interactive keeps them"; _ai_agent_claude --interactive --tools read hello' \
    'lessons-mark|fixture|functions -q _ai_review_comments; _ai_review_comments_anchor ../comments.json HEAD~1..HEAD (pwd) 3 >../lr.comments.json; _ai_review_comments_md ../lr.comments.json ../verify.md >../lr.comments.md; cp ../review.md ../lr.md; cp ../verify.md ../lr.verify.md; echo "- [F4] **gbranch: a bare name is ambiguous** - two files match" >>../lr.md; awk -f ../lessons-marks.awk ../lr.comments.md >../lr.tmp; mv ../lr.tmp ../lr.comments.md; echo "== dry run"; ai lessons mark --dry-run ../lr.comments.md | head -1; test -f (ai lessons path)/outcomes.jsonl; or echo "nothing written"; echo "== mark"; ai lessons mark ../lr.comments.md; echo "== the log"; jq -c "del(.date, .file, .key)" (ai lessons path)/outcomes.jsonl; echo "== the marks now"; string match -e -r "^ *Outcome: [^_]" <../lr.comments.md; echo "== again"; ai lessons mark ../lr.comments.md; echo "== stats"; ai lessons stats | string replace -r -a "\d{4}-\d{2}-\d{2}" "<date>"; echo "== run lines"; functions -q _ai_lessons; printf "x\n---\nRun: [1/3] Review - ollama - qwen3.8:27b | 299s | turns 6\n" >../rm.md; _ai_lessons_run_model ../rm.md Review; printf "Run: [2/3] Verify - litellm - qwen/qwen3.8-27b | 9s\nRun: [2/3] Verify - litellm - qwen/qwen3.8-27b | 8s\n" >../rm.md; _ai_lessons_run_model ../rm.md Verify; echo "== the run number after the model: one model"; printf "Run: [1/3] Review ×3 - litellm - qwen/qwen3.8-27b run 1/3 | 71s\nRun: [1/3] Review ×3 - litellm - qwen/qwen3.8-27b run 2/3 | 9s\n" >../rm.md; _ai_lessons_run_model ../rm.md Review; echo "== claude names no model"; printf "Run: [1/3] Review - claude | 118s | prompt ~94k tokens (estimate)\n" >../rm.md; _ai_lessons_run_model ../rm.md Review; echo "== a vote file: the models of its runs"; printf "Verify: 1 confirmed\n" >../rv.verify.md; printf "Run: [2/3] Verify ×2 - litellm - qwen/qwen3.8-27b run 1/2 | 9s\n" >../rv.verify.run1.md; printf "Run: [2/3] Verify ×2 - litellm - qwen/qwen3.8-27b run 2/2 | 9s\n" >../rv.verify.run2.md; _ai_lessons_run_model ../rv.verify.md Verify; echo "== no runs at all: nothing"; printf "Verify: 1 confirmed\n" >../rn.verify.md; echo "[$(_ai_lessons_run_model ../rn.verify.md Verify)]"' \
    'lessons-where|fixture|set -gx XDG_DATA_HOME (path resolve ../lw-data); functions -q _ai_review_comments; _ai_review_comments_anchor ../comments.json HEAD~1..HEAD (pwd) 3 >../lw.comments.json; _ai_review_comments_md ../lw.comments.json ../verify.md | awk -f ../lessons-marks.awk >../lw.comments.md; echo "== the JSON names the repository"; jq -c ".repo | {root: (.root | length > 0), origin}" ../lw.comments.json; for k in 2 3; cp ../lw.comments.md ../lw$k.comments.md; end; jq ".repo = {root: \"/gone\", origin: \"git@gitlab.example.com:group/proj.git\"}" ../lw.comments.json >../lw2.comments.json; jq "del(.repo)" ../lw.comments.json >../lw3.comments.json; cd ..; echo "== from outside the repository"; ai lessons mark lw.comments.md; echo "== the repository gone, its origin left"; ai lessons mark lw2.comments.md; echo "== nothing to go by"; ai lessons mark lw3.comments.md' \
    'lessons-registry|fixture|set -gx XDG_DATA_HOME (path resolve ../lg-data); set -gx EDITOR echo; functions -q _ai_review_comments; function _c; cp ../review.md ../rg$argv[1].md; _ai_review_comments --findings ../rg$argv[1].md --verdicts ../verify-refuted.md --output ../rg$argv[1].md --provider testcloud --range HEAD~1..HEAD --quiet 2>/dev/null; end; function _ls; ai lessons | string replace -r "\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}" "<date>"; end; echo "== none yet"; ai lessons; _c 1; _c 2; echo "== two reviews"; _ls; string replace "  Outcome: _" "  Outcome: missed" <../rg1.comments.md >../rg.tmp; mv ../rg.tmp ../rg1.comments.md; echo "== one marked"; _ls; echo "== open"; ai lessons open; ai lessons open 2; ai lessons open 3; echo "== mark, no file, outside the repository"; cd ..; ai lessons mark; echo "== again"; ai lessons mark; cd fixture; echo "== written again: first"; _c 2; _c 1; _ls; echo "== a file gone"; rm ../rg2.comments.md; _ls; echo "== no such file"; ai lessons mark nope.comments.md' \
    'lessons-errors|fixture|functions -q _ai_review_comments; _ai_review_comments_anchor ../comments.json HEAD~1..HEAD (pwd) 3 >../lb.comments.json; _ai_review_comments_md ../lb.comments.json ../verify.md >../lb.comments.md; cp ../review.md ../lb.md; cp ../verify.md ../lb.verify.md; awk -f ../lessons-bad.awk ../lb.comments.md >../lb.tmp; mv ../lb.tmp ../lb.comments.md; set -l log (ai lessons path)/outcomes.jsonl; set -l before (count (cat $log 2>/dev/null)); ai lessons mark ../lb.comments.md 2>&1 | string replace -r ":\d+:" ":<n>:"; echo "lines logged: "(math (count (cat $log 2>/dev/null)) - $before); echo "== no file"; ai lessons mark ../nope.comments.md; echo "== unknown"; ai lessons frob' \
    'lessons-guard|fixture|functions -q _ai_review_comments; cp ../review.md ../g.md; printf "Outcome: +\n" >../g.comments.md; _ai_review_comments --findings ../g.md --verdicts ../verify-refuted.md --output ../g.md --provider testcloud --range HEAD~1..HEAD; echo "rc $status"; printf "Outcome: + (logged)\n" >../g.comments.md; _ai_review_comments --findings ../g.md --verdicts ../verify-refuted.md --output ../g.md --provider testcloud --range HEAD~1..HEAD --quiet 2>/dev/null; echo "rc $status"; head -3 ../g.comments.md' \
    'lessons-dir|fixture|functions -q _ai_lessons; _ai_lessons_dir; for u in git@gitlab.example.com:group/proj.git https://user@gitlab.example.com/group/proj.git/ ssh://git@gitlab.example.com:2222/group/proj.git; git remote add origin $u; _ai_lessons_dir; git remote remove origin; end; mkdir -p .ai; echo lessons_dir=.lessons >.ai/config; _ai_lessons_dir; rm -rf .ai; set -gx XDG_DATA_HOME /data; _ai_lessons_dir; set -e XDG_DATA_HOME; cd ..; ai lessons path' \
    'models-unregister|fixture|cp ~/.pi/agent/models.json ../pi-saved.json; mkdir -p ~/.config/opencode; printf "{\"provider\":{\"ollama\":{\"models\":{\"review-model\":{\"tools\":true},\"other:7b\":{\"tools\":true}}}}}" >~/.config/opencode/config.json; echo "== not listed"; _ai_models_unregister --yes nosuch:1b; echo "rc $status"; echo "== declined"; echo n | _ai_models_unregister review-model:latest; jq -c "[.providers.ollama.models[].id]" ~/.pi/agent/models.json; echo "== yes"; _ai_models_unregister --yes review-model:latest; jq -c "[.providers.ollama.models[].id]" ~/.pi/agent/models.json; jq -c ".provider.ollama.models | keys" ~/.config/opencode/config.json; jq -c "[.providers.ollama.models[].id]" ~/.pi/agent/models.json.bak; cp ../pi-saved.json ~/.pi/agent/models.json; rm -rf ~/.config/opencode ~/.pi/agent/models.json.bak' \
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
    'openai-too-big|fixture|string repeat -n 5000 x | _ai_provider_openai --provider testcloud --model cloud-model; echo "== 300 numbered lines: 3 tokens a line on top of their chars"; seq 300 | _ai_number_lines | _ai_provider_openai --provider testcloud --model cloud-model' \
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
    'help-stop|fixture|ai stop --help' \
    'help-lessons|fixture|ai lessons --help'

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
