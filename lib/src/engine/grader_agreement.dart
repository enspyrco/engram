import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import '../models/assessment.dart';
import 'fsrs_engine.dart';

/// How often the blind assessor gives the rating a person gave the same
/// answer.
///
/// Over-rating is reported apart from under-rating because the two do
/// different harm: an over-rated card is scheduled later than the learner can
/// hold it, and is forgotten.
typedef GraderAgreement =
    ({
      int count,
      int exact,
      int withinOne,
      int overRated,
      int underRated,

      /// `confusion[human][grader]` counts answers by both ratings.
      IMap<FsrsRating, IMap<FsrsRating, int>> confusion,
    });

GraderAgreement agreementOf(
  Iterable<({FsrsRating human, FsrsRating grader})> pairs,
) {
  var count = 0, exact = 0, withinOne = 0, overRated = 0, underRated = 0;
  final confusion = {
    for (final h in FsrsRating.values)
      h: {for (final g in FsrsRating.values) g: 0},
  };
  for (final (:human, :grader) in pairs) {
    count++;
    final gap = grader.index - human.index;
    if (gap == 0) exact++;
    if (gap.abs() <= 1) withinOne++;
    if (gap > 0) overRated++;
    if (gap < 0) underRated++;
    confusion[human]![grader] = confusion[human]![grader]! + 1;
  }
  return (
    count: count,
    exact: exact,
    withinOne: withinOne,
    overRated: overRated,
    underRated: underRated,
    confusion:
        {
          for (final MapEntry(:key, :value) in confusion.entries)
            key: value.lock,
        }.lock,
  );
}

/// Signs of lazy evidence in one receipt: citations that are real words of
/// the answer but may not show what they are cited for. Real words are
/// guaranteed; relevance is not, so it is counted here rather than guarded.
typedef LazyEvidence =
    ({
      /// Citations of a single token.
      int oneToken,

      /// Citations covering more than half the answer's tokens.
      int overHalf,

      /// Criterion citations that repeat another criterion's citation exactly.
      int reused,
    });

LazyEvidence lazyEvidenceOf(AssessmentReceipt receipt, AnswerText answer) {
  final criterionSpans = [
    for (final j in receipt.judgements)
      if (j.evidence case final Span span) span,
  ];
  final spans = [
    ...criterionSpans,
    for (final m in receipt.misconceptions) m.evidence,
  ];
  final half = answer.tokens.length / 2;
  return (
    oneToken: spans.where((s) => s.length == 1).length,
    overHalf: spans.where((s) => s.length > half).length,
    reused: criterionSpans.length - criterionSpans.toSet().length,
  );
}
