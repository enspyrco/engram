/// SM-2 spaced repetition algorithm result.
class Sm2Result {
  const Sm2Result({
    required this.easeFactor,
    required this.interval,
    required this.repetitions,
  });

  final double easeFactor;
  final int interval;
  final int repetitions;
}

/// Pure SM-2 algorithm.
///
/// [quality] is 0-5 where:
///   0 = complete blackout
///   1 = incorrect, but recognized on reveal
///   2 = incorrect, but answer felt easy on reveal
///   3 = correct with serious difficulty
///   4 = correct with some hesitation
///   5 = perfect response
///
/// Returns updated ease factor, interval (days), and repetition count.
Sm2Result sm2({
  required int quality,
  required double easeFactor,
  required int interval,
  required int repetitions,
}) {
  assert(quality >= 0 && quality <= 5, 'Quality must be 0-5');

  if (quality < 3) {
    // Failed: reset repetitions and interval
    return Sm2Result(
      easeFactor: _clampEaseFactor(
        easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)),
      ),
      interval: 1,
      repetitions: 0,
    );
  }

  // Successful recall
  final newRepetitions = repetitions + 1;
  int newInterval;

  if (newRepetitions == 1) {
    newInterval = 1;
  } else if (newRepetitions == 2) {
    newInterval = 6;
  } else {
    newInterval = (interval * easeFactor).round();
  }

  final newEaseFactor = _clampEaseFactor(
    easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)),
  );

  return Sm2Result(
    easeFactor: newEaseFactor,
    interval: newInterval,
    repetitions: newRepetitions,
  );
}

double _clampEaseFactor(double ef) => ef < 1.3 ? 1.3 : ef;
