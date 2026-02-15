import 'package:fsrs/fsrs.dart' as fsrs;

/// FSRS rating for a quiz review (4-point scale).
///
/// Maps to SM-2's 0-5 scale in Phase 2:
///   0-1 → again, 2 → hard, 3 → good, 4-5 → easy
enum FsrsRating {
  again,
  hard,
  good,
  easy;

  fsrs.Rating _toFsrs() {
    switch (this) {
      case FsrsRating.again:
        return fsrs.Rating.again;
      case FsrsRating.hard:
        return fsrs.Rating.hard;
      case FsrsRating.good:
        return fsrs.Rating.good;
      case FsrsRating.easy:
        return fsrs.Rating.easy;
    }
  }
}

/// Result of an FSRS review or initialization.
class FsrsResult {
  const FsrsResult({
    required this.difficulty,
    required this.stability,
    required this.fsrsState,
    required this.lapses,
    required this.intervalDays,
    required this.nextReview,
  });

  /// Card difficulty (1.0-10.0). Mean-reverts over time, solving SM-2 ease hell.
  final double difficulty;

  /// Memory stability in days — the interval at which recall = 90%.
  final double stability;

  /// FSRS state: 1=learning, 2=review, 3=relearning.
  final int fsrsState;

  /// Number of times the card lapsed (review → relearning).
  final int lapses;

  /// Scheduled interval in days.
  final int intervalDays;

  /// When the card is next due for review.
  final DateTime nextReview;
}

/// Review a card using the FSRS algorithm.
///
/// Pure function — creates a [fsrs.Scheduler] and [fsrs.Card] internally,
/// runs the review, and maps the result back to [FsrsResult].
/// The rest of the codebase never imports `package:fsrs` directly.
FsrsResult reviewFsrs({
  required FsrsRating rating,
  required double difficulty,
  required double stability,
  required int fsrsState,
  required int lapses,
  required DateTime lastReview,
  DateTime? now,
  double desiredRetention = 0.9,
}) {
  final currentTime = now ?? DateTime.now().toUtc();

  final scheduler = fsrs.Scheduler(
    desiredRetention: desiredRetention,
    enableFuzzing: false,
    // Empty steps: cards graduate to review state immediately.
    // QuizItem uses day-based intervals; minute-based learning steps
    // can be added in Phase 2 if needed.
    learningSteps: const [],
    relearningSteps: const [],
  );

  final card = fsrs.Card(
    cardId: 0,
    state: fsrs.State.fromValue(fsrsState),
    stability: stability,
    difficulty: difficulty,
    due: currentTime,
    lastReview: lastReview,
  );

  // Track lapses: increment when rating is "again" while in review state
  final newLapses =
      (rating == FsrsRating.again && fsrsState == fsrs.State.review.value)
          ? lapses + 1
          : lapses;

  final (card: reviewedCard, reviewLog: _) = scheduler.reviewCard(
    card,
    rating._toFsrs(),
    reviewDateTime: currentTime,
  );

  final intervalDays = reviewedCard.due.difference(currentTime).inDays;

  return FsrsResult(
    difficulty: reviewedCard.difficulty!,
    stability: reviewedCard.stability!,
    fsrsState: reviewedCard.state.value,
    lapses: newLapses,
    intervalDays: intervalDays,
    nextReview: reviewedCard.due,
  );
}

/// Create initial FSRS state from Claude's predicted difficulty.
///
/// Sets difficulty from prediction (clamped to 1.0-10.0) and stability
/// from the FSRS "good" initial parameter (~3.26 days). This ensures
/// the first [reviewFsrs] call uses the "existing card" update path
/// (mean reversion) rather than overwriting both from the rating.
FsrsResult initializeFsrsCard({
  double? predictedDifficulty,
  DateTime? now,
}) {
  final currentTime = now ?? DateTime.now().toUtc();

  final difficulty = predictedDifficulty != null
      ? predictedDifficulty.clamp(1.0, 10.0)
      : 5.0;

  // Use "good" initial stability from FSRS default parameters
  final stability = fsrs.defaultParameters[2];

  return FsrsResult(
    difficulty: difficulty,
    stability: stability,
    fsrsState: fsrs.State.learning.value,
    lapses: 0,
    intervalDays: 0,
    nextReview: currentTime,
  );
}

/// Compute the probability that a card is correctly recalled right now.
///
/// Uses the FSRS power-law forgetting curve. Returns 0.0 if stability
/// is zero or negative.
double fsrsRetrievability({
  required double stability,
  required int fsrsState,
  required DateTime lastReview,
  DateTime? now,
}) {
  if (stability <= 0) return 0.0;

  final currentTime = now ?? DateTime.now().toUtc();

  final scheduler = fsrs.Scheduler();
  final card = fsrs.Card(
    cardId: 0,
    state: fsrs.State.fromValue(fsrsState),
    stability: stability,
    difficulty: 5.0, // doesn't affect retrievability calculation
    lastReview: lastReview,
    due: currentTime,
  );

  return scheduler.getCardRetrievability(card, currentDateTime: currentTime);
}
