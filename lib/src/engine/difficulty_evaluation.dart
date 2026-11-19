import '../models/quiz_item.dart';

/// Coarse difficulty band used to score Claude's difficulty predictions.
enum DifficultyBand {
  /// 1.0-3.0: pure fact recall.
  low('Low', '1-3'),

  /// 3.1-6.0: mechanism/process.
  medium('Medium', '4-6'),

  /// 6.1-10.0: synthesis/abstract reasoning.
  high('High', '7-10');

  const DifficultyBand(this.label, this.range);

  /// Display name, e.g. `Low`.
  final String label;

  /// Rounded difficulty range shown to Claude, e.g. `1-3`.
  final String range;
}

/// Returns the difficulty band for a given difficulty value (1.0-10.0).
DifficultyBand difficultyBand(double difficulty) {
  if (difficulty <= 3.0) return DifficultyBand.low;
  if (difficulty <= 6.0) return DifficultyBand.medium;
  return DifficultyBand.high;
}

/// Evaluate how well Claude's predicted difficulties match FSRS actuals.
///
/// Pure function (follows `fsrs_engine.dart` pattern). Filters to items
/// with [QuizItem.predictedDifficulty] != null and
/// [QuizItem.reviewCount] >= [minReviews].
DifficultyEvaluationResult evaluatePredictions(
  List<QuizItem> items, {
  int minReviews = 5,
}) {
  final withPrediction =
      items.where((q) => q.predictedDifficulty != null).toList();
  final totalPredicted = withPrediction.length;

  final evaluated =
      withPrediction.where((q) => q.reviewCount >= minReviews).toList();

  if (evaluated.isEmpty) {
    return DifficultyEvaluationResult(
      evaluatedCount: 0,
      totalPredicted: totalPredicted,
      meanAbsoluteError: null,
      bandAccuracy: const {},
    );
  }

  // Compute mean absolute error
  var totalError = 0.0;
  var evaluatedCount = 0;
  final bandCorrect = {for (final band in DifficultyBand.values) band: 0};
  final bandPredicted = {for (final band in DifficultyBand.values) band: 0};

  for (final item in evaluated) {
    final predicted = item.predictedDifficulty!;
    // After 5+ reviews, FSRS difficulty is always set. Skip items with
    // null difficulty defensively (shouldn't happen in practice).
    if (item.difficulty == null) continue;
    final actual = item.difficulty!;
    evaluatedCount++;

    totalError += (predicted - actual).abs();

    final predictedBand = difficultyBand(predicted);
    final actualBand = difficultyBand(actual);
    bandPredicted[predictedBand] = bandPredicted[predictedBand]! + 1;
    if (predictedBand == actualBand) {
      bandCorrect[predictedBand] = bandCorrect[predictedBand]! + 1;
    }
  }

  if (evaluatedCount == 0) {
    return DifficultyEvaluationResult(
      evaluatedCount: 0,
      totalPredicted: totalPredicted,
      meanAbsoluteError: null,
      bandAccuracy: const {},
    );
  }

  final bandAccuracy = <DifficultyBand, BandAccuracy>{};
  for (final band in DifficultyBand.values) {
    final predicted = bandPredicted[band]!;
    if (predicted > 0) {
      bandAccuracy[band] = BandAccuracy(
        correct: bandCorrect[band]!,
        predicted: predicted,
      );
    }
  }

  return DifficultyEvaluationResult(
    evaluatedCount: evaluatedCount,
    totalPredicted: totalPredicted,
    meanAbsoluteError: totalError / evaluatedCount,
    bandAccuracy: bandAccuracy,
  );
}

/// Result of evaluating Claude's difficulty predictions against FSRS actuals.
class DifficultyEvaluationResult {
  const DifficultyEvaluationResult({
    required this.evaluatedCount,
    required this.totalPredicted,
    required this.meanAbsoluteError,
    required this.bandAccuracy,
  });

  /// Creates an empty result (no data to evaluate).
  factory DifficultyEvaluationResult.empty() =>
      const DifficultyEvaluationResult(
        evaluatedCount: 0,
        totalPredicted: 0,
        meanAbsoluteError: null,
        bandAccuracy: {},
      );

  /// Number of cards with enough reviews to evaluate.
  final int evaluatedCount;

  /// Total number of cards with a prediction (regardless of review count).
  final int totalPredicted;

  /// Mean absolute error between predicted and actual difficulty.
  /// Null when [evaluatedCount] is 0.
  final double? meanAbsoluteError;

  /// Per-band accuracy: how often the predicted band matched the actual band.
  /// Only populated bands are present.
  final Map<DifficultyBand, BandAccuracy> bandAccuracy;
}

/// Accuracy for a single difficulty band.
class BandAccuracy {
  const BandAccuracy({required this.correct, required this.predicted});

  /// Number of cards where the predicted band matched the actual band.
  final int correct;

  /// Total cards predicted in this band.
  final int predicted;
}
