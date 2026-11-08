# Fills the Outcome marks of a comments file as a person would in the editor: the first
# three comments right, a false positive with its reason, and unsure; the comment on F4
# right; the first refuted entry a missed bug, the second rightly refuted; the rest unmarked.
BEGIN {
    c[1] = "+"
    c[2] = "- reads GBRANCH_BASES, not a fixed list"
    c[3] = "~"
}
/^### .*\| F4$/ { f4 = 1 }
/^Outcome: _$/ && f4 { $0 = "Outcome: +"; f4 = 0 }
/^Outcome: _$/ && ++n <= 3 { $0 = "Outcome: " c[n] }
/^  Outcome: _$/ && ++m <= 2 { $0 = "  Outcome: " (m == 1 ? "missed" : "+") }
{ print }
