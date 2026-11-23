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

/// Words the grader quoted that really appear, in order, in the learner's
/// answer.
///
/// Matching is on whole words, ignoring case and punctuation, so "correct"
/// is not found in "incorrect". A quote must be at least two words unless it
/// is the whole answer, so a single common word cannot stand as evidence.
@immutable
final class Quote {
  const Quote._(this.text);

  /// The quote as the grader wrote it.
  final String text;

  /// The quote if [quoted] is found in [answer], otherwise null.
  static Quote? find(String answer, String quoted) {
    final needle = _words(quoted);
    final haystack = _words(answer);
    if (needle.isEmpty) return null;
    if (needle.length < 2 && needle.length != haystack.length) return null;
    for (var start = 0; start + needle.length <= haystack.length; start++) {
      var matches = true;
      for (var i = 0; i < needle.length; i++) {
        if (haystack[start + i] != needle[i]) {
          matches = false;
          break;
        }
      }
      if (matches) return Quote._(quoted.trim());
    }
    return null;
  }

  static final _word = RegExp(r'[\p{L}\p{N}]+', unicode: true);

  static List<String> _words(String s) => [
    for (final m in _word.allMatches(s.toLowerCase())) m[0]!,
  ];
}

/// The grader's judgement of one rubric criterion. A met or partial
/// judgement always carries the learner's words that support it.
@immutable
final class CriterionJudgement {
  const CriterionJudgement._(this.criterion, this.verdict, this.evidence);

  const CriterionJudgement.met(String criterion, Quote evidence)
    : this._(criterion, CriterionVerdict.met, evidence);

  const CriterionJudgement.partial(String criterion, Quote evidence)
    : this._(criterion, CriterionVerdict.partial, evidence);

  const CriterionJudgement.missed(String criterion)
    : this._(criterion, CriterionVerdict.missed, null);

  final String criterion;
  final CriterionVerdict verdict;

  /// Null exactly when [verdict] is [CriterionVerdict.missed].
  final Quote? evidence;
}

/// A wrong claim the answer makes, with the learner's words that make it.
@immutable
final class Misconception {
  const Misconception(this.claim, this.evidence);

  /// The grader's description of what is wrong.
  final String claim;
  final Quote evidence;
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

  final IList<Misconception> misconceptions;

  /// One line for the learner.
  final String feedback;

  /// Judgements and misconceptions the grader gave without a quote found in
  /// the answer. Such a judgement counts as missed; such a misconception is
  /// dropped.
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
  IList<Misconception> misconceptions = const IListConst([]),
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

/// The grader judged the answer.
final class Graded extends AssessmentOutcome {
  const Graded(this.receipt);
  final AssessmentReceipt receipt;
}

/// The answer was blank, so nothing was sent to the grader. The caller
/// rates it [FsrsRating.again].
final class Unanswered extends AssessmentOutcome {
  const Unanswered();
}

final class GradingFailed extends AssessmentOutcome {
  const GradingFailed(this.failure, this.detail);
  final GradingFailure failure;
  final String detail;
}
