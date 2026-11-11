function _ai_review_number_findings --description "Number the findings of a review (stdin → stdout): every top-level bullet or list item outside the Summary, Nits and other non-defect sections gets [F1], [F2]… once"
    # Verify keys each verdict by the number, so several verify runs can be joined by it
    # and a verdict matched back to its finding without comparing reworded titles.
    # Deterministic, no model: a finding is a top-level "- " / "* " bullet or "1. " item under
    # a section heading — or a bullet indented by 1-3 spaces right under the heading, not under
    # a top-level bullet ("2. **Critical issues**" then "   - …"). Left unnumbered, such a run
    # had no verdicts, or verify runs numbered it themselves and their F1 met the real F1 of
    # another run in the vote. Only numbered findings get a verdict, so sections that hold no
    # defects stay unnumbered: Summary, Nits, Architecture, Strengths, Verdict, a held-back
    # tally. A verdict on each of them only inflated the count ("unused import" CONFIRMED;
    # 12 of 30 on one review). A deny list, not an allow list: a section the model named
    # its own way ("## Bugs") is still verified. A heading is "## X", or "**X**" / "**3. X**" /
    # "3. **X** —" when X is a section name (so "1. **Lost updates** — …" stays a finding), or
    # a plain "3. Important issues" that is the section name alone (a bare trailing dash too).
    # Missed headings left a run unnumbered, and verify runs keyed its findings their own way:
    # the vote merged different findings under one number.
    # A finding written as "### 1. Missing handler" under a section gets the number, and its
    # bullets ("Consequence: …") are its details, not findings: numbered one by one they made
    # three verdicts of one finding and left the finding itself without one. Lines inside a
    # ``` block are code: a removed diff line "- def receiptDocument…" was numbered as a finding.
    # Numbers run across the "## Run K/N" parts of a joined review. Already numbered input
    # passes through unchanged, so numbering twice (the flow, then verify) is harmless. A run
    # that wrote its findings as headings keeps no numbers: verify falls back to titles there.
    # Via a file: a command substitution does not read the function's stdin
    set -l tmp (mktemp)
    cat >$tmp
    if grep -q -E '^( {0,3}([-*]|[0-9]+\.)|#{3,}) \[F[0-9]+\] ' $tmp
        cat $tmp
        rm -f $tmp
        return 0
    end
    # The section name is its first Latin word, past any leading mark ("## [!] Critical"). A
    # heading with no Latin word at all (the model translated it, though the prompt asks for
    # the format's English names) is a section of its own, "other", verified like "## Bugs":
    # its name cannot be read, and an unread name numbered nothing under it. A non-ASCII
    # byte sorts after "~" (awk compares bytes here).
    awk '
        function section(line,   s, p, n, i) {
            s = line; sub(/^[#0-9. ]*\*?\*?[0-9. ]*/, "", s)
            n = split(s, p, /[^A-Za-z]+/)
            for (i = 1; i <= n; i++) if (p[i] != "") return tolower(p[i])
            return (s ~ /[^ -~]/ || substr(s, 1, 1) > "~") ? "other" : ""
        }
        function known(name) {
            return name ~ /^(summary|critical|important|tests?|removed|nits?|security|findings|issues|verdict|architecture|strengths?|held)$/
        }
        # Sections whose bullets are not defects: no number, so no verdict and no comment
        function plain(name) {
            return name ~ /^(summary|nits?|architecture|strengths?|verdict|held)$/
        }
        # "3. Important issues" with no bold: a heading only when the item is the section
        # name alone (then ":" or " — …"), so "1. Tests are missing for X" stays a finding
        function plainhead(line,   s) {
            s = line; sub(/^[0-9]+\. /, "", s); sub(/:.*$/, "", s); sub(/ +(—|–|-)( .*)?$/, "", s)
            s = tolower(s); sub(/ +$/, "", s)
            return s ~ /^(summary|critical( issues)?|important( issues)?|tests?|removed( code)?|nits?|security( issues)?|findings|issues|verdict|architecture|strengths?)$/
        }
        # top: inside a top-level bullet, so an indented bullet is its sub-bullet;
        # hf: under a finding written as a "### …" heading, so its bullets are details
        /^## Run [0-9]+\// { sec = ""; top = 0; hf = 0; print; next }
        /^ *```/ { fence = !fence; print; next }
        fence { print; next }
        /^## / { sec = section($0); top = 0; hf = 0; print; next }
        /^###+ / && known(section($0)) { sec = section($0); top = 0; hf = 0; print; next }
        /^###+ / && sec != "" && !plain(sec) {
            match($0, /^#+ /)
            n++; print substr($0, 1, RLENGTH) "[F" n "] " substr($0, RLENGTH + 1); top = 0; hf = 1; next
        }
        /^(\*\*|\*\*[0-9]+\. |[0-9]+\. \*\*)/ && known(section($0)) { sec = section($0); top = 0; hf = 0; print; next }
        /^[0-9]+\. [A-Z]/ && plainhead($0) { sec = section($0); top = 0; hf = 0; print; next }
        /^([-*]|[0-9]+\.) / { top = 1 }
        sec != "" && !plain(sec) && !hf && (/^([-*]|[0-9]+\.) / || (!top && /^ {1,3}[-*] /)) {
            # "- (none)" in an empty tier is not a finding, nor "- (none) — the removed X is
            # fine": verify only confirmed that nothing is wrong
            t = $0; sub(/^ *([-*]|[0-9]+\.) /, "", t); t = tolower(t); gsub(/[*_.[:space:]]/, "", t)
            if (t ~ /^\(none\)/ || t ~ /^none([^a-z]|$)/) { print; next }
            match($0, /^ *([-*]|[0-9]+\.) /)
            n++; print substr($0, 1, RLENGTH) "[F" n "] " substr($0, RLENGTH + 1); next
        }
        { print }
    ' $tmp
    rm -f $tmp
end
