import 'package:engram/src/services/notification_service.dart';
import 'package:test/test.dart';

void main() {
  group('buildNotificationCopy', () {
    test('all caught up with no new concepts → skip', () {
      final copy = buildNotificationCopy(
        dueCount: 0,
        daysSinceLastSession: 1,
        currentStreak: 5,
        hasNewConcepts: false,
      );

      expect(copy.skip, isTrue);
      expect(copy.title, 'All caught up!');
    });

    test('new concepts available → explores message', () {
      final copy = buildNotificationCopy(
        dueCount: 3,
        daysSinceLastSession: 1,
        currentStreak: 2,
        hasNewConcepts: true,
      );

      expect(copy.skip, isFalse);
      expect(copy.title, 'New concepts to explore');
      expect(copy.body, contains('Plus 3 due'));
    });

    test('new concepts with no due → no "Plus" suffix', () {
      final copy = buildNotificationCopy(
        dueCount: 0,
        daysSinceLastSession: 1,
        currentStreak: 0,
        hasNewConcepts: true,
      );

      expect(copy.skip, isFalse);
      expect(copy.title, 'New concepts to explore');
      expect(copy.body, isNot(contains('Plus')));
    });

    test('long absence → welcome back message', () {
      final copy = buildNotificationCopy(
        dueCount: 10,
        daysSinceLastSession: 5,
        currentStreak: 0,
        hasNewConcepts: false,
      );

      expect(copy.skip, isFalse);
      expect(copy.title, 'Welcome back!');
      expect(copy.body, contains('10 concepts'));
    });

    test('active streak → streak message', () {
      final copy = buildNotificationCopy(
        dueCount: 4,
        daysSinceLastSession: 1,
        currentStreak: 7,
        hasNewConcepts: false,
      );

      expect(copy.skip, isFalse);
      expect(copy.title, '7-day streak!');
      expect(copy.body, contains('4 concepts'));
    });

    test('default → generic review message', () {
      final copy = buildNotificationCopy(
        dueCount: 3,
        daysSinceLastSession: 1,
        currentStreak: 1,
        hasNewConcepts: false,
      );

      expect(copy.skip, isFalse);
      expect(copy.title, 'Time to review!');
      expect(copy.body, contains('3 concepts'));
    });

    test('singular grammar for 1 concept', () {
      final copy = buildNotificationCopy(
        dueCount: 1,
        daysSinceLastSession: 1,
        currentStreak: 1,
        hasNewConcepts: false,
      );

      expect(copy.body, contains('1 concept'));
      expect(copy.body, isNot(contains('concepts')));
    });

    test('null daysSinceLastSession (first user) → default message', () {
      final copy = buildNotificationCopy(
        dueCount: 5,
        daysSinceLastSession: null,
        currentStreak: 0,
        hasNewConcepts: false,
      );

      expect(copy.skip, isFalse);
      expect(copy.title, 'Time to review!');
    });
  });
}
