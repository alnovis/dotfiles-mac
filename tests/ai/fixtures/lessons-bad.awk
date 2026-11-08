# Marks a person can get wrong: a "-" with no reason, "missed" on a comment, a word that
# is no mark, and "-" on a refuted entry.
BEGIN {
    c[1] = "-"
    c[2] = "missed"
    c[3] = "yes"
}
/^Outcome: _$/ && ++n <= 3 { $0 = "Outcome: " c[n] }
/^  Outcome: _$/ && ++m <= 1 { $0 = "  Outcome: - not a bug" }
{ print }
