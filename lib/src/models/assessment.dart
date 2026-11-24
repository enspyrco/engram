import 'dart:convert';

import 'package:crypto/crypto.dart';
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
}

/// One run of non-whitespace in an answer, with its character offsets.
typedef AnswerToken = ({String text, int start, int end});

/// A learner's answer exactly as written, and the tokens a grader cites it
/// by.
///
/// A token is a maximal run of non-whitespace; its offsets index the
/// untrimmed answer. Nothing is normalized, so a cited token is always
/// byte-for-byte the learner's.
@immutable
final class AnswerText {
  const AnswerText._(this.text, this.tokens);

  factory AnswerText.of(String text) => AnswerText._(
    text,
    [
      for (final m in _token.allMatches(text))
        (text: m[0]!, start: m.start, end: m.end),
    ].lock,
  );

  static final _token = RegExp(r'\S+');

  /// How this tokenizer splits a fixed probe of every kind of whitespace,
  /// punctuation and script, with offsets. It is part of the grader version,
  /// so any change to what the grader sees as tokens changes the version,
  /// whether the change is in the pattern or in the code around it.
  static final tokenizerFingerprint = jsonEncode([
    for (final t in AnswerText.of(_probe).tokens) [t.text, t.start, t.end],
  ]);

  static const _probe =
      ' a  b\tc\nd\r\ne f g​h﻿i "j" (k), -5 x!=y '
      '\\l 東京は首都 é é. ';

  final String text;
  final IList<AnswerToken> tokens;

  bool get isBlank => tokens.isEmpty;
}

/// Consecutive tokens of the learner's answer, cited as evidence.
///
/// Only [Span.of] builds one, and only when the grader's position and its
/// copied tokens agree, so a span is always an exact slice of the answer.
@immutable
final class Span {
  const Span._({
    required this.start,
    required this.end,
    required this.charStart,
    required this.charEnd,
    required this.text,
  });

  /// The span whose first token is at [start] in [answer], if the answer's
  /// tokens from there equal [tokens] by raw string equality; otherwise null.
  static Span? of(AnswerText answer, int start, List<String> tokens) {
    final all = answer.tokens;
    // Subtracting keeps both sides small: `start + tokens.length` wraps
    // negative for a start near the int maximum, which the grader can send.
    if (tokens.isEmpty || start < 0 || start > all.length - tokens.length) {
      return null;
    }
    for (final (i, token) in tokens.indexed) {
      if (all[start + i].text != token) return null;
    }
    final first = all[start];
    final last = all[start + tokens.length - 1];
    return Span._(
      start: start,
      end: start + tokens.length,
      charStart: first.start,
      charEnd: last.end,
      text: answer.text.substring(first.start, last.end),
    );
  }

  /// The first token's position; [end] is one past the last token.
  final int start;
  final int end;

  /// Character offsets of [text] in the answer.
  final int charStart;
  final int charEnd;

  /// The cited words exactly as the learner wrote them, spacing included.
  final String text;

  int get length => end - start;

  @override
  bool operator ==(Object other) =>
      other is Span &&
      other.start == start &&
      other.end == end &&
      other.charStart == charStart &&
      other.text == text;

  @override
  int get hashCode => Object.hash(start, end, charStart, text);

  @override
  String toString() => 'Span($start..$end: $text)';
}

/// The grader's judgement of one rubric criterion. A met or partial
/// judgement always carries the learner's words that support it.
@immutable
final class CriterionJudgement {
  const CriterionJudgement._(this.criterion, this.verdict, this.evidence);

  const CriterionJudgement.met(String criterion, Span evidence)
    : this._(criterion, CriterionVerdict.met, evidence);

  const CriterionJudgement.partial(String criterion, Span evidence)
    : this._(criterion, CriterionVerdict.partial, evidence);

  const CriterionJudgement.missed(String criterion)
    : this._(criterion, CriterionVerdict.missed, null);

  final String criterion;
  final CriterionVerdict verdict;

  /// Null exactly when [verdict] is [CriterionVerdict.missed].
  final Span? evidence;
}

/// A wrong claim the answer makes, with the learner's words that make it.
@immutable
final class Misconception {
  const Misconception(this.claim, this.evidence);

  /// The grader's description of what is wrong.
  final String claim;
  final Span evidence;
}

/// How criterion judgements become an FSRS rating. The grader never picks
/// the rating, and never gives [FsrsRating.easy]: a written answer shows
/// what was recalled, not how effortlessly.
enum RatingPolicy {
  /// [FsrsRating.good] when every criterion is met; [FsrsRating.hard] when
  /// none is missed and at least one is partial; otherwise
  /// [FsrsRating.again]. Any misconception is [FsrsRating.again].
  nothingMissed;

  FsrsRating rate(
    Iterable<CriterionVerdict> verdicts, {
    required bool misconceived,
  }) => switch (this) {
    RatingPolicy.nothingMissed =>
      verdicts.isEmpty ||
              misconceived ||
              verdicts.contains(CriterionVerdict.missed)
          ? FsrsRating.again
          : verdicts.contains(CriterionVerdict.partial)
          ? FsrsRating.hard
          : FsrsRating.good,
  };
}

/// The Claude model the grader runs on.
@immutable
final class GraderModel {
  const GraderModel._(this.id);

  static const opus55 = GraderModel._('claude-opus-5-5');

  static final _shape = RegExp(r'^claude-[a-z0-9][a-z0-9.-]*$');

  /// Reads a model id; null unless it looks like a Claude model id.
  static GraderModel? parse(String raw) =>
      _shape.hasMatch(raw) ? GraderModel._(raw) : null;

  /// The id sent to the API.
  final String id;

  @override
  bool operator ==(Object other) => other is GraderModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => id;
}

/// A digest of what the grader model is shown: its prompt, its tool schema
/// and how answers are tokenized. Derived from their bytes, so any edit to
/// them changes it without anyone remembering to.
///
/// It does not cover the rules that read the grader's reply back (which
/// citations resolve, what makes a reply malformed). Code cannot hash
/// itself, so a change to those rules must be treated as a new version by
/// hand.
@immutable
final class PromptDigest {
  const PromptDigest._(this.hex);

  /// The first 12 hex digits of the SHA-256 of [promptBytes].
  factory PromptDigest.of(List<int> promptBytes) =>
      PromptDigest._(sha256.convert(promptBytes).toString().substring(0, 12));

  final String hex;

  @override
  bool operator ==(Object other) => other is PromptDigest && other.hex == hex;

  @override
  int get hashCode => hex.hashCode;

  @override
  String toString() => hex;
}

/// Which grader produced a receipt and how its judgements are rated, so
/// receipts from a changed prompt, model or policy are never pooled with
/// older ones, and a version that passed acceptance is exactly one version.
typedef GraderVersion =
    ({PromptDigest prompt, GraderModel model, RatingPolicy policy});

/// What the blind assessor decided about one answer, and why.
@immutable
final class AssessmentReceipt {
  const AssessmentReceipt({
    required this.judgements,
    required this.misconceptions,
    required this.feedback,
    required this.graderVersion,
  });

  /// One judgement per rubric criterion, in rubric order.
  final IList<CriterionJudgement> judgements;

  /// Wrong claims the answer makes, each cited from it.
  final IList<Misconception> misconceptions;

  /// One line for the learner.
  final String feedback;

  final GraderVersion graderVersion;

  FsrsRating get rating => graderVersion.policy.rate(
    judgements.map((j) => j.verdict),
    misconceived: misconceptions.isNotEmpty,
  );
}

/// Why the assessor produced no receipt. The caller writes
/// [FsrsRating.again].
enum GradingFailure {
  /// The grader replied without calling the grading tool.
  noToolCall,

  /// The tool call did not hold one valid judgement per criterion.
  malformed,

  /// A citation's tokens are not the answer's tokens at its position.
  unresolvedCitation,

  /// The request to the grader failed.
  requestFailed,
}

sealed class AssessmentOutcome {
  const AssessmentOutcome();

  /// The rating to write to the schedule. Only a successful grading can
  /// lengthen the interval; there is no self-rating fallback.
  FsrsRating get scheduledRating;
}

/// The grader judged the answer.
final class Graded extends AssessmentOutcome {
  const Graded(this.receipt);
  final AssessmentReceipt receipt;

  @override
  FsrsRating get scheduledRating => receipt.rating;
}

/// The answer was blank, so nothing was sent to the grader.
final class Unanswered extends AssessmentOutcome {
  const Unanswered();

  @override
  FsrsRating get scheduledRating => FsrsRating.again;
}

/// The grader could not grade the answer. Again never lengthens the
/// interval, and it takes the card out of the due queue, so a card the
/// grader cannot grade is not stuck there.
final class GradingFailed extends AssessmentOutcome {
  const GradingFailed(this.failure, this.detail);
  final GradingFailure failure;
  final String detail;

  @override
  FsrsRating get scheduledRating => FsrsRating.again;
}
