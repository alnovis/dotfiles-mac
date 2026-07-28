function _ai_verify_output_path --description "Derive the verify-pass output path from a review output path"
    # review_up_ctx.md  -> review_up_ctx.verify.md
    # report            -> report.verify
    # Keeps the directory; inserts `.verify` before the final extension.
    set -l p $argv[1]
    set -l dir (dirname -- "$p")
    set -l base (basename -- "$p")
    if string match -qr '\.[^.]+$' -- "$base"
        set base (string replace -r '\.([^.]+)$' '.verify.$1' -- "$base")
    else
        set base "$base.verify"
    end
    if test "$dir" = "."
        echo "$base"
    else
        echo "$dir/$base"
    end
end
