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
      expect(copy.title, contains('caught up'));
    });

    test('new concepts available → explores message', () {
      final copy = buildNotificationCopy(
        dueCount: 3,
        daysSinceLastSession: 1,
        currentStreak: 2,
        hasNewConcepts: true,
      );

      expect(copy.skip, isFalse);
      expect(copy.title, contains('concepts'));
      expect(copy.body, contains('3'));
      expect(copy.body, contains('due'));
    });

    test('new concepts with no due → no "Plus" suffix', () {
      final copy = buildNotificationCopy(
        dueCount: 0,
        daysSinceLastSession: 1,
        currentStreak: 0,
        hasNewConcepts: true,
      );

      expect(copy.skip, isFalse);
      expect(copy.title, contains('concepts'));
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
      expect(copy.title, contains('Welcome back'));
      expect(copy.body, contains('10'));
    });

    test('active streak → streak message', () {
      final copy = buildNotificationCopy(
        dueCount: 4,
        daysSinceLastSession: 1,
        currentStreak: 7,
        hasNewConcepts: false,
      );

      expect(copy.skip, isFalse);
      expect(copy.title, contains('streak'));
      expect(copy.body, contains('4'));
    });

    test('default → generic review message', () {
      final copy = buildNotificationCopy(
        dueCount: 3,
        daysSinceLastSession: 1,
        currentStreak: 1,
        hasNewConcepts: false,
      );

      expect(copy.skip, isFalse);
      expect(copy.title, contains('review'));
      expect(copy.body, contains('3'));
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
      expect(copy.title, contains('review'));
    });
  });
}
