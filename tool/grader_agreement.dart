// Measures how often the blind assessor agrees with a person.
//
//   ANTHROPIC_API_KEY=... dart run tool/grader_agreement.dart gold.jsonl
//
// Each line of the gold set is one answer a person has graded against its
// rubric, one verdict per criterion, plus any wrong claims it makes:
//   {"question": "...", "reference_answer": "...", "rubric": ["...", "..."],
//    "learner_answer": "...", "human_verdicts": ["met", "partial"],
//    "human_misconceptions": ["..."]}
//
// The person's verdicts are rated by the same policy as the grader's, so the
// two ratings are compared like for like. Split the gold set before the
// first run: calibrate on one file, and run the other once, untouched.
//
// The verdicts must come from a person. Verdicts written by a model measure
// agreement between two models, not whether the grader is right.

import 'dart:convert';
import 'dart:io';

import 'package:engram/src/engine/fsrs_engine.dart';
import 'package:engram/src/engine/grader_agreement.dart';
import 'package:engram/src/models/assessment.dart';
import 'package:engram/src/models/rubric.dart';
import 'package:engram/src/services/blind_assessor.dart';

typedef _GoldAnswer =
    ({
      int line,
      String question,
      String referenceAnswer,
      Rubric rubric,
      AnswerText learnerAnswer,
      List<CriterionVerdict> humanVerdicts,
      bool humanMisconceived,
    });

/// Answers grouped by how many tokens a citation can choose from. A
/// one-token answer is often a script without spaces, a URL or a code blob,
/// where citations audit little.
enum _AnswerLength {
  oneToken('1 token'),
  short('2-10 tokens'),
  long('over 10 tokens');

  const _AnswerLength(this.label);
  final String label;

  static _AnswerLength of(AnswerText answer) => switch (answer.tokens.length) {
    <= 1 => oneToken,
    <= 10 => short,
    _ => long,
  };
}

_GoldAnswer? _parseLine(int line, String text) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;
  final question = decoded['question'];
  final reference = decoded['reference_answer'];
  final learner = decoded['learner_answer'];
  final rubric = Rubric.parse(decoded['rubric']);
  final rawVerdicts = decoded['human_verdicts'];
  final rawMisconceptions = decoded['human_misconceptions'];
  if (question is! String ||
      reference is! String ||
      learner is! String ||
      rubric == null ||
      rawVerdicts is! List ||
      rawMisconceptions is! List ||
      rawMisconceptions.any((m) => m is! String)) {
    return null;
  }
  if (rawVerdicts.length != rubric.criteria.length) return null;
  final verdicts = <CriterionVerdict>[];
  for (final raw in rawVerdicts) {
    final verdict = CriterionVerdict.parse(raw);
    if (verdict == null) return null;
    verdicts.add(verdict);
  }
  return (
    line: line,
    question: question,
    referenceAnswer: reference,
    rubric: rubric,
    learnerAnswer: AnswerText.of(learner),
    humanVerdicts: verdicts,
    humanMisconceived: rawMisconceptions.isNotEmpty,
  );
}

Future<void> main(List<String> args) async {
  final apiKey = Platform.environment['ANTHROPIC_API_KEY'];
  if (args.length != 1 || apiKey == null || apiKey.isEmpty) {
    stderr.writeln(
      'usage: ANTHROPIC_API_KEY=... dart run tool/grader_agreement.dart <gold.jsonl>',
    );
    exitCode = 64;
    return;
  }

  final gold = <_GoldAnswer>[];
  final List<String> lines;
  try {
    lines = File(args.single).readAsLinesSync();
  } on FileSystemException catch (e) {
    stderr.writeln('cannot read ${args.single}: ${e.message}');
    exitCode = 66;
    return;
  }
  for (final (i, text) in lines.indexed) {
    if (text.trim().isEmpty) continue;
    final answer = _parseLine(i + 1, text);
    if (answer == null) {
      stderr.writeln('line ${i + 1}: not a valid gold answer');
      exitCode = 65;
      return;
    }
    gold.add(answer);
  }

  final assessor = BlindAssessor(apiKey: apiKey);
  final version = assessor.graderVersion;
  final pairs = <({FsrsRating human, FsrsRating grader})>[];
  var unanswered = 0, requestFailures = 0;
  var oneToken = 0, overHalf = 0, reused = 0;
  final answeredBy = {for (final l in _AnswerLength.values) l: 0};
  final gradedBy = {for (final l in _AnswerLength.values) l: 0};
  final failures = <String>[];
  for (final answer in gold) {
    final outcome = await assessor.assess(
      question: answer.question,
      referenceAnswer: answer.referenceAnswer,
      rubric: answer.rubric,
      production: answer.learnerAnswer,
    );
    if (outcome is Unanswered) {
      unanswered++;
      continue;
    }
    final length = _AnswerLength.of(answer.learnerAnswer);
    answeredBy[length] = answeredBy[length]! + 1;
    final human = version.policy.rate(
      answer.humanVerdicts,
      misconceived: answer.humanMisconceived,
    );
    // A failed grading counts as the Again it writes to the schedule.
    pairs.add((human: human, grader: outcome.scheduledRating));
    switch (outcome) {
      case Graded(:final receipt):
        gradedBy[length] = gradedBy[length]! + 1;
        final lazy = lazyEvidenceOf(receipt, answer.learnerAnswer);
        oneToken += lazy.oneToken;
        overHalf += lazy.overHalf;
        reused += lazy.reused;
        if (receipt.rating != human) {
          stdout.writeln(
            'line ${answer.line}: person ${human.name}, '
            'grader ${receipt.rating.name}: ${receipt.feedback}',
          );
        }
      case GradingFailed(:final failure, :final detail):
        if (failure == GradingFailure.requestFailed) requestFailures++;
        failures.add(
          'line ${answer.line} (${length.label}): ${failure.name}: $detail',
        );
      case Unanswered():
        break;
    }
  }

  final a = agreementOf(pairs);
  String pct(int n, int of) =>
      of == 0 ? '-' : '${(100 * n / of).toStringAsFixed(0)}%';
  final graded = a.count - failures.length;
  stdout
    ..writeln()
    ..writeln(
      'Grader: ${version.model}, prompt ${version.prompt}, '
      'policy ${version.policy.name}',
    )
    ..writeln(
      'Answered ${a.count} of ${gold.length}; $unanswered blank, not sent',
    )
    ..writeln('Coverage: graded $graded (${pct(graded, a.count)})');
  for (final length in _AnswerLength.values) {
    stdout.writeln(
      '  ${length.label}: ${gradedBy[length]} of ${answeredBy[length]} '
      '(${pct(gradedBy[length]!, answeredBy[length]!)})',
    );
  }
  stdout
    ..writeln('Among answered, a failed grading counted as again:')
    ..writeln(
      '  same rating as the person: ${a.exact} (${pct(a.exact, a.count)})',
    )
    ..writeln('  grader higher: ${a.overRated} (${pct(a.overRated, a.count)})')
    ..writeln('  grader lower: ${a.underRated} (${pct(a.underRated, a.count)})')
    // Real words cited for the wrong reason are invisible to every check;
    // these counts are where lazy citation would show.
    ..writeln('Citations of one token: $oneToken')
    ..writeln('Citations of more than half the answer: $overHalf')
    ..writeln('Criterion citations reused across criteria: $reused')
    ..writeln()
    ..writeln(
      'person \\ grader  ${FsrsRating.values.map((r) => r.name.padLeft(6)).join()}',
    );
  for (final human in FsrsRating.values) {
    final row = a.confusion[human]!;
    stdout.writeln(
      '${human.name.padRight(16)}${FsrsRating.values.map((g) => '${row[g]}'.padLeft(6)).join()}',
    );
  }
  for (final failure in failures) {
    stderr.writeln(failure);
  }
  // A request that never reached the grader says nothing about it, so a run
  // with one, or with nothing answered, is not a measurement.
  if (requestFailures > 0 || a.count == 0) exitCode = 1;
}
