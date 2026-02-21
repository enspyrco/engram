/// Result of computing the streak after a completed session.
class StreakUpdate {
  const StreakUpdate({
    required this.currentStreak,
    required this.longestStreak,
    required this.lastSessionDate,
  });

  final int currentStreak;
  final int longestStreak;

  /// ISO 8601 date string (yyyy-MM-dd) of this session.
  final String lastSessionDate;
}

/// Result of inspecting how long the user has been away.
class AbsenceInfo {
  const AbsenceInfo({
    required this.daysSinceLastSession,
    required this.isComeback,
  });

  final int daysSinceLastSession;

  /// True when the gap is long enough to warrant a gentler re-entry (>3 days).
  final bool isComeback;
}

/// Compute the new streak state after completing a quiz session.
///
/// Handles: first session ever, same-day repeat, consecutive day, broken streak.
StreakUpdate computeStreakAfterSession({
  required String? lastSessionDateIso,
  required int previousStreak,
  required int previousLongest,
  required DateTime now,
}) {
  final todayStr = _dateString(now);

  if (lastSessionDateIso == null) {
    // First session ever
    return StreakUpdate(
      currentStreak: 1,
      longestStreak: 1,
      lastSessionDate: todayStr,
    );
  }

  if (lastSessionDateIso == todayStr) {
    // Same-day session — streak unchanged
    return StreakUpdate(
      currentStreak: previousStreak,
      longestStreak: previousLongest,
      lastSessionDate: todayStr,
    );
  }

  final lastDate = DateTime.parse(lastSessionDateIso);
  final today = DateTime.parse(todayStr);
  final gap = today.difference(lastDate).inDays;

  if (gap == 1) {
    // Consecutive day — extend streak
    final newStreak = previousStreak + 1;
    return StreakUpdate(
      currentStreak: newStreak,
      longestStreak: newStreak > previousLongest ? newStreak : previousLongest,
      lastSessionDate: todayStr,
    );
  }

  // Gap > 1 day — streak broken, start fresh
  return StreakUpdate(
    currentStreak: 1,
    longestStreak: previousLongest > 1 ? previousLongest : 1,
    lastSessionDate: todayStr,
  );
}

/// Inspect how long it's been since the last session.
///
/// Returns `null` if there's no previous session (first-time user).
AbsenceInfo? inspectAbsence({
  required String? lastSessionDateIso,
  required DateTime now,
}) {
  if (lastSessionDateIso == null) return null;

  final lastDate = DateTime.parse(lastSessionDateIso);
  final today = DateTime.parse(_dateString(now));
  final days = today.difference(lastDate).inDays;

  return AbsenceInfo(daysSinceLastSession: days, isComeback: days > 3);
}

/// Format a DateTime as yyyy-MM-dd for date-only comparison.
String _dateString(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
