require 'diff/lcs'

seq1 = %w(a b c e h j l m n p)
seq2 = %w(b c d e f j k l m r s t)

lcs = Diff::LCS.LCS(seq1, seq2)
p lcs
diffs = Diff::LCS.diff(seq1, seq2)
p diffs
sdiff = Diff::LCS.sdiff(seq1, seq2)
p sdiff
#seq = Diff::LCS.traverse_sequences(seq1, seq2, callback_obj)
#bal = Diff::LCS.traverse_balanced(seq1, seq2, callback_obj)
#seq2 == Diff::LCS.patch!(seq1, diffs)
#seq1 == Diff::LCS.unpatch!(seq2, diffs)
#seq2 == Diff::LCS.patch!(seq1, sdiff)
#seq1 == Diff::LCS.unpatch!(seq2, sdiff)