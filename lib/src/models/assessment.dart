import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:meta/meta.dart';

import '../engine/fsrs_engine.dart';

/// How fully a learner's answer meets one rubric criterion.
enum CriterionVerdict {
  met,
  partial,
  missed;

  /// Reads a verdict from the grader's tool output; null for anything else.
  static CriterionVerdict? parse(Object? raw) {
    for (final verdict in values) {
      if (verdict.name == raw) return verdict;
    }
    return null;
  }

  double get credit => switch (this) {
    CriterionVerdict.met => 1,
    CriterionVerdict.partial => 0.5,
    CriterionVerdict.missed => 0,
  };
}

/// The grader's judgement of one rubric criterion, with the learner's own
/// words that support it.
@immutable
final class CriterionJudgement {
  const CriterionJudgement({
    required this.criterion,
    required this.verdict,
    required this.evidence,
  });

  final String criterion;
  final CriterionVerdict verdict;

  /// A verbatim quote from the learner's answer; null when the verdict is
  /// [CriterionVerdict.missed].
  final String? evidence;
}

/// Which grader produced a receipt, so receipts from a changed prompt or
/// model are never pooled with older ones when measuring agreement.
typedef GraderVersion = ({int promptRevision, String model});

/// What the blind assessor decided about one answer, and why.
@immutable
final class AssessmentReceipt {
  const AssessmentReceipt({
    required this.judgements,
    required this.misconceptions,
    required this.feedback,
    required this.unsupportedCount,
    required this.graderVersion,
  });

  /// One judgement per rubric criterion, in rubric order.
  final IList<CriterionJudgement> judgements;

  /// Wrong claims the answer makes, in the grader's words.
  final IList<String> misconceptions;

  /// One line for the learner.
  final String feedback;

  /// Judgements the grader marked met or partial whose quote is not in the
  /// answer; they are counted as missed.
  final int unsupportedCount;

  final GraderVersion graderVersion;

  FsrsRating get rating =>
      ratingFor(judgements, misconceptions: misconceptions);
}

/// Turns criterion judgements into an FSRS rating.
///
/// All criteria met with no misconception is [FsrsRating.good]; at least half
/// the rubric's credit is [FsrsRating.hard], and a misconception caps the
/// rating there; less is [FsrsRating.again]. The grader never gives
/// [FsrsRating.easy]: a written answer shows what was recalled, not how
/// effortlessly.
FsrsRating ratingFor(
  IList<CriterionJudgement> judgements, {
  IList<String> misconceptions = const IListConst([]),
}) {
  if (judgements.isEmpty) return FsrsRating.again;
  final credit = judgements.fold<double>(0, (sum, j) => sum + j.verdict.credit);
  final fraction = credit / judgements.length;
  if (fraction == 1 && misconceptions.isEmpty) return FsrsRating.good;
  if (fraction >= 0.5) return FsrsRating.hard;
  return FsrsRating.again;
}

/// Why the assessor produced no receipt. The caller falls back to
/// self-rating.
enum GradingFailure {
  /// The grader replied without calling the grading tool.
  noToolCall,

  /// The tool call did not hold one valid judgement per criterion.
  malformed,

  /// The request to the grader failed.
  requestFailed,
}

sealed class AssessmentOutcome {
  const AssessmentOutcome();
}

final class Graded extends AssessmentOutcome {
  const Graded(this.receipt);
  final AssessmentReceipt receipt;
}

final class GradingFailed extends AssessmentOutcome {
  const GradingFailed(this.failure, this.detail);
  final GradingFailure failure;
  final String detail;
}
