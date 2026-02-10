import 'package:engram/src/engine/streak.dart';
import 'package:test/test.dart';

void main() {
  group('computeStreakAfterSession', () {
    test('first session ever → streak = 1', () {
      final result = computeStreakAfterSession(
        lastSessionDateIso: null,
        previousStreak: 0,
        previousLongest: 0,
        now: DateTime.utc(2025, 6, 15),
      );

      expect(result.currentStreak, 1);
      expect(result.longestStreak, 1);
      expect(result.lastSessionDate, '2025-06-15');
    });

    test('same-day session → streak unchanged', () {
      final result = computeStreakAfterSession(
        lastSessionDateIso: '2025-06-15',
        previousStreak: 3,
        previousLongest: 5,
        now: DateTime.utc(2025, 6, 15, 18, 30),
      );

      expect(result.currentStreak, 3);
      expect(result.longestStreak, 5);
      expect(result.lastSessionDate, '2025-06-15');
    });

    test('consecutive day → streak incremented', () {
      final result = computeStreakAfterSession(
        lastSessionDateIso: '2025-06-14',
        previousStreak: 3,
        previousLongest: 5,
        now: DateTime.utc(2025, 6, 15),
      );

      expect(result.currentStreak, 4);
      expect(result.longestStreak, 5);
      expect(result.lastSessionDate, '2025-06-15');
    });

    test('consecutive day updates longest when surpassed', () {
      final result = computeStreakAfterSession(
        lastSessionDateIso: '2025-06-14',
        previousStreak: 5,
        previousLongest: 5,
        now: DateTime.utc(2025, 6, 15),
      );

      expect(result.currentStreak, 6);
      expect(result.longestStreak, 6);
    });

    test('gap of 2+ days → streak resets to 1', () {
      final result = computeStreakAfterSession(
        lastSessionDateIso: '2025-06-10',
        previousStreak: 4,
        previousLongest: 7,
        now: DateTime.utc(2025, 6, 15),
      );

      expect(result.currentStreak, 1);
      expect(result.longestStreak, 7);
      expect(result.lastSessionDate, '2025-06-15');
    });

    test('streak broken preserves longest', () {
      final result = computeStreakAfterSession(
        lastSessionDateIso: '2025-06-12',
        previousStreak: 2,
        previousLongest: 2,
        now: DateTime.utc(2025, 6, 15),
      );

      expect(result.currentStreak, 1);
      expect(result.longestStreak, 2);
    });
  });

  group('inspectAbsence', () {
    test('returns null for first-time user', () {
      final result = inspectAbsence(
        lastSessionDateIso: null,
        now: DateTime.utc(2025, 6, 15),
      );

      expect(result, isNull);
    });

    test('same day → 0 days, not comeback', () {
      final result = inspectAbsence(
        lastSessionDateIso: '2025-06-15',
        now: DateTime.utc(2025, 6, 15, 20, 0),
      );

      expect(result!.daysSinceLastSession, 0);
      expect(result.isComeback, isFalse);
    });

    test('1 day gap → not comeback', () {
      final result = inspectAbsence(
        lastSessionDateIso: '2025-06-14',
        now: DateTime.utc(2025, 6, 15),
      );

      expect(result!.daysSinceLastSession, 1);
      expect(result.isComeback, isFalse);
    });

    test('3 day gap → not comeback (boundary)', () {
      final result = inspectAbsence(
        lastSessionDateIso: '2025-06-12',
        now: DateTime.utc(2025, 6, 15),
      );

      expect(result!.daysSinceLastSession, 3);
      expect(result.isComeback, isFalse);
    });

    test('4+ day gap → is comeback', () {
      final result = inspectAbsence(
        lastSessionDateIso: '2025-06-11',
        now: DateTime.utc(2025, 6, 15),
      );

      expect(result!.daysSinceLastSession, 4);
      expect(result.isComeback, isTrue);
    });

    test('long absence → is comeback with correct count', () {
      final result = inspectAbsence(
        lastSessionDateIso: '2025-05-01',
        now: DateTime.utc(2025, 6, 15),
      );

      expect(result!.daysSinceLastSession, 45);
      expect(result.isComeback, isTrue);
    });
  });
}
