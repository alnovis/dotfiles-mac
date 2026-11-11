function _ai_verify_vote --description "Join N verify runs by majority per finding number: args N FILE…; prints one verdict per finding, then the tally"
    # Each run keys its verdicts by the finding numbers [F1], [F2]… (_ai_review_number_findings).
    # A verdict wins when more than half of the N runs gave it: 2 of 3, 3 of 4, 2 of 2.
    # Anything else — runs that disagree, a finding only some runs judged — is UNCERTAIN.
    # The kept title and why: come from the winning run with the highest confidence; a
    # "votes:" line shows every run's verdict. Verdicts without a finding number cannot be
    # matched across runs and are left out, with a count.
    # Column K of "votes:" is run K, taken from the file name (<dest>.runK): a failed run
    # leaves no file, and its column stays "-" instead of the next run's moving into it.
    set -l n $argv[1]
    set -l files $argv[2..]
    awk -v N=$n '
        # The em and en dashes the models write, as octal bytes: the source stays ASCII
        BEGIN {
            EM = "\342\200\224"; EN = "\342\200\223"
            BARE = "(" EM "|" EN "|-|[*][*])[[:space:]]*[*]*[[:space:]]*(CONFIRMED|REFUTED|UNCERTAIN)([[:space:]]+[0-9]+[[:space:]]*/[[:space:]]*10)?[[:space:]]*[*]*[[:space:]]*$"
        }
        function flush() {
            if (id != "" && v != "" && !((RUN, id) in seen)) {
                seen[RUN, id] = 1
                verdict[id, RUN] = v; conf[id, RUN] = c; title[id, RUN] = t; why[id, RUN] = w
                ids[id] = 1
            }
            id = ""; v = ""; c = ""; t = ""; w = ""
        }
        # A bare verdict is read as _ai_verdict_counts reads it: at the end of the line, after
        # a dash or in bold. A why: line may say "not REFUTED" and is no verdict.
        function tag_of(l,   s) {
            if (match(l, /\[(CONFIRMED|REFUTED|UNCERTAIN)[^]]*\]/)) return substr(l, RSTART + 1, RLENGTH - 2)
            if (match(l, BARE)) {
                s = substr(l, RSTART, RLENGTH); sub(/^[^A-Z]*/, "", s); gsub(/[[:space:]*]+$/, "", s); return s
            }
            return ""
        }
        FNR == 1 {
            flush(); FNUM++; RUN = FNUM
            if (match(FILENAME, /\.run[0-9]+(\.[^.\/]*)?$/)) { s = substr(FILENAME, RSTART + 4); sub(/\..*$/, "", s); RUN = s + 0 }
            if (RUN > RUNS) RUNS = RUN
        }
        {
            line = $0
            g = tag_of(line)
            # A finding starts where its [Fn] leads the line (after list, heading or bold
            # marks); an [Fn] further in, as in "why: unlike [F2] ...", only mentions one
            if (match(line, /\[F[0-9]+\]/) && substr(line, 1, RSTART - 1) ~ /^[[:space:]>#*|0-9.)-]*$/) {
                flush()
                id = substr(line, RSTART + 2, RLENGTH - 3) + 0
                t = line
            } else if (line ~ /^[[:space:]]*([-*]|\*\*)/) {
                # A bullet with its own text but no number is another finding, not part of
                # the one above; a bare "- [CONFIRMED 6/10]" line still belongs to its title
                rest = line; sub(/\[(CONFIRMED|REFUTED|UNCERTAIN)[^]]*\]/, "", rest)
                sub(/(CONFIRMED|REFUTED|UNCERTAIN)([[:space:]]+[0-9]+[[:space:]]*\/[[:space:]]*10)?[[:space:]*]*$/, "", rest)
                gsub(/[-*[:space:]—–]/, "", rest)
                if (rest != "") { flush(); if (g != "") unnumbered++; next }
            }
            if (g != "") {
                if (id == "") { unnumbered++; next }
                if (v == "") {
                    split(g, p, " "); v = p[1]
                    if (match(g, /[0-9]+[ ]*\/[ ]*10/)) { c = substr(g, RSTART, RLENGTH); sub(/[ ]*\/.*/, "", c) }
                }
                next
            }
            if (id != "" && w == "" && line ~ /^[[:space:]]*why:/) { w = line; sub(/^[[:space:]]*why:[[:space:]]*/, "", w) }
        }
        END {
            flush()
            k = 0
            for (i in ids) order[++k] = i + 0
            # numeric sort of the finding numbers
            for (a = 2; a <= k; a++) { x = order[a]; b = a - 1; while (b >= 1 && order[b] > x) { order[b + 1] = order[b]; b-- } order[b + 1] = x }
            need = int(N / 2) + 1
            printf "Majority of %d verify runs, joined by finding number: a verdict needs %d of %d.\n\n", N, need, N
            nc = nr = nu = 0
            if (RUNS < N) RUNS = N
            for (a = 1; a <= k; a++) {
                i = order[a]; cc = rr = uu = 0; votes = ""
                for (f = 1; f <= RUNS; f++) {
                    if (!((i, f) in verdict)) { votes = votes " -"; continue }
                    vv = verdict[i, f]; letter = substr(vv, 1, 1)
                    votes = votes " " letter conf[i, f]
                    if (vv == "CONFIRMED") cc++; else if (vv == "REFUTED") rr++; else uu++
                }
                win = "UNCERTAIN"
                if (cc >= need) win = "CONFIRMED"; else if (rr >= need) win = "REFUTED"
                # title and why: the winning run with the highest confidence; for UNCERTAIN, any run
                best = 0; bc = -1
                for (f = 1; f <= RUNS; f++) {
                    if (!((i, f) in verdict)) continue
                    if (win != "UNCERTAIN" && verdict[i, f] != win) continue
                    cf = conf[i, f] + 0
                    if (best == 0 || cf > bc) { best = f; bc = cf }
                }
                tt = title[i, best]
                sub(/^[[:space:]]*[-*]?[[:space:]]*/, "", tt); sub(/\[F[0-9]+\][[:space:]]*/, "", tt)
                sub(/[[:space:]]*[—–-]*[[:space:]]*\**[[:space:]]*\[?(CONFIRMED|REFUTED|UNCERTAIN).*$/, "", tt)
                gsub(/\*\*/, "", tt); sub(/[[:space:]—–-]+$/, "", tt)
                if (win == "UNCERTAIN") { tag = "[UNCERTAIN]"; nu++ }
                else {
                    sum = 0; m = 0
                    for (f = 1; f <= RUNS; f++) if ((i, f) in verdict && verdict[i, f] == win && conf[i, f] != "") { sum += conf[i, f]; m++ }
                    tag = "[" win (m > 0 ? " " int(sum / m + 0.5) "/10" : "") "]"
                    if (win == "CONFIRMED") nc++; else nr++
                }
                printf "- [F%d] %s — %s\n", i, tt, tag
                ww = why[i, best]
                judged = cc + rr + uu
                if (win == "UNCERTAIN") {
                    why0 = (judged < need) ? "only " judged " of " N " runs judged it" : "the runs disagree (votes below)"
                    ww = why0 (ww != "" ? "; one run: " ww : "")
                }
                printf "  why: %s\n", ww
                printf "  votes:%s (C confirmed, R refuted, U uncertain, - not judged)\n\n", votes
            }
            if (unnumbered > 0) printf "%d verdict(s) without a finding number were left out: they cannot be matched across runs.\n\n", unnumbered
            printf "Verify: %d confirmed, %d refuted, %d uncertain (majority of %d runs)\n", nc, nr, nu, N
        }
    ' $files
end
