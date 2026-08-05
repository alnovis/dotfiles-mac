function _ai_thinking_output_path --description "Derive the reasoning-sidecar path from a report output path"
    # review_d.md  -> review_d.thinking.md
    # report       -> report.thinking
    # Keeps the directory; inserts `.thinking` before the final extension. Mirrors
    # _ai_verify_output_path so the review, its verify pass, and its reasoning trace
    # form a consistent <base>.<kind>.<ext> family next to each other.
    set -l p $argv[1]
    set -l dir (dirname -- "$p")
    set -l base (basename -- "$p")
    if string match -qr '\.[^.]+$' -- "$base"
        set base (string replace -r '\.([^.]+)$' '.thinking.$1' -- "$base")
    else
        set base "$base.thinking"
    end
    if test "$dir" = "."
        echo "$base"
    else
        echo "$dir/$base"
    end
end
