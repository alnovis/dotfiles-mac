function _ai_verify_wanted --description "Decide if the verify pass runs: --verify > review_verify config; --no-verify wins"
    # Args (caller passes flag presence, since fish flags are not visible here):
    #   $argv[1] = "1" if --verify was given, else ""
    #   $argv[2] = "1" if --no-verify was given, else ""
    # Returns 0 (run verify) / 1 (skip).
    set -l has_flag $argv[1]
    set -l has_no $argv[2]

    test -n "$has_no"; and return 1
    test -n "$has_flag"; and return 0

    set -l cfg (_ai_config_read review_verify)
    if test $status -eq 0; and contains -- "$cfg" 1 true yes on
        return 0
    end
    return 1
end
