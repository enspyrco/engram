// Measures how often the blind assessor agrees with a person.
//
//   ANTHROPIC_API_KEY=... dart run tool/grader_agreement.dart gold.jsonl
//
// Each line of the gold set is one answer a person has rated:
//   {"question": "...", "reference_answer": "...", "rubric": ["...", "..."],
//    "learner_answer": "...", "human_rating": "again|hard|good|easy"}
//
// The human ratings must come from a person. Ratings written by a model
// measure agreement between two models, not whether the grader is right.

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
      String learnerAnswer,
      FsrsRating humanRating,
    });

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
  final human = FsrsRating.values.asNameMap()[decoded['human_rating']];
  if (question is! String ||
      reference is! String ||
      learner is! String ||
      rubric == null ||
      human == null) {
    return null;
  }
  return (
    line: line,
    question: question,
    referenceAnswer: reference,
    rubric: rubric,
    learnerAnswer: learner,
    humanRating: human,
  );
}

Future<void> main(List<String> args) async {
  final apiKey = Platform.environment['ANTHROPIC_API_KEY'];
  if (args.length != 1 || apiKey == null || apiKey.isEmpty) {
    stderr.writeln(
      'usage: ANTHROPIC_API_KEY=... dart run tool/grader_agreement.dart <gold.jsonl>',
    );
    exit(64);
  }

  final gold = <_GoldAnswer>[];
  final lines = File(args.single).readAsLinesSync();
  for (final (i, text) in lines.indexed) {
    if (text.trim().isEmpty) continue;
    final answer = _parseLine(i + 1, text);
    if (answer == null) {
      stderr.writeln('line ${i + 1}: not a valid gold answer');
      exit(65);
    }
    gold.add(answer);
  }

  final assessor = BlindAssessor(apiKey: apiKey);
  final pairs = <({FsrsRating human, FsrsRating grader})>[];
  var unsupported = 0;
  final failures = <String>[];
  for (final answer in gold) {
    final outcome = await assessor.assess(
      question: answer.question,
      referenceAnswer: answer.referenceAnswer,
      rubric: answer.rubric,
      production: answer.learnerAnswer,
    );
    switch (outcome) {
      case Graded(:final receipt):
        pairs.add((human: answer.humanRating, grader: receipt.rating));
        unsupported += receipt.unsupportedCount;
        if (receipt.rating != answer.humanRating) {
          stdout.writeln(
            'line ${answer.line}: person ${answer.humanRating.name}, '
            'grader ${receipt.rating.name}: ${receipt.feedback}',
          );
        }
      case GradingFailed(:final failure, :final detail):
        failures.add('line ${answer.line}: ${failure.name}: $detail');
    }
  }

  final a = agreementOf(pairs);
  String pct(int n) =>
      a.count == 0 ? '-' : '${(100 * n / a.count).toStringAsFixed(0)}%';
  final version = assessor.graderVersion;
  stdout
    ..writeln()
    ..writeln(
      'Grader: ${version.model}, prompt revision ${version.promptRevision}',
    )
    ..writeln('Graded ${a.count} of ${gold.length}; ${failures.length} failed')
    ..writeln('Same rating as the person: ${a.exact} (${pct(a.exact)})')
    ..writeln('Within one step: ${a.withinOne} (${pct(a.withinOne)})')
    ..writeln('Grader higher: ${a.overRated} (${pct(a.overRated)})')
    ..writeln('Grader lower: ${a.underRated} (${pct(a.underRated)})')
    ..writeln('Quotes not found in the answer: $unsupported')
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
}
