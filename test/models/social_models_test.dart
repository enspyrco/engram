import 'package:engram/src/models/challenge.dart';
import 'package:engram/src/models/friend.dart';
import 'package:engram/src/models/mastery_snapshot.dart';
import 'package:engram/src/models/nudge.dart';
import 'package:test/test.dart';

void main() {
  group('MasterySnapshot', () {
    test('fromJson/toJson round-trip', () {
      const snapshot = MasterySnapshot(
        totalConcepts: 50,
        mastered: 20,
        learning: 15,
        newCount: 15,
        streak: 7,
      );

      final json = snapshot.toJson();
      final restored = MasterySnapshot.fromJson(json);

      expect(restored.totalConcepts, 50);
      expect(restored.mastered, 20);
      expect(restored.learning, 15);
      expect(restored.newCount, 15);
      expect(restored.streak, 7);
    });

    test('masteryRatio computes correctly', () {
      const snapshot = MasterySnapshot(totalConcepts: 10, mastered: 3);
      expect(snapshot.masteryRatio, closeTo(0.3, 0.001));
    });

    test('masteryRatio handles zero concepts', () {
      const snapshot = MasterySnapshot();
      expect(snapshot.masteryRatio, 0.0);
    });
  });

  group('Friend', () {
    test('fromJson/toJson round-trip', () {
      const friend = Friend(
        uid: 'f1',
        displayName: 'Bob',
        photoUrl: 'https://photo.url/bob.jpg',
        masterySnapshot: MasterySnapshot(totalConcepts: 10, mastered: 5),
        lastActiveAt: '2025-06-01T00:00:00.000Z',
      );

      final json = friend.toJson();
      final restored = Friend.fromJson(json);

      expect(restored.uid, 'f1');
      expect(restored.displayName, 'Bob');
      expect(restored.photoUrl, 'https://photo.url/bob.jpg');
      expect(restored.masterySnapshot!.mastered, 5);
    });

    test('fromJson handles null masterySnapshot', () {
      final friend = Friend.fromJson(const {
        'uid': 'f1',
        'displayName': 'Bob',
      });

      expect(friend.masterySnapshot, isNull);
    });
  });

  group('Challenge', () {
    test('fromJson/toJson round-trip', () {
      const challenge = Challenge(
        id: 'c1',
        fromUid: 'user1',
        fromName: 'Alice',
        toUid: 'user2',
        quizItemSnapshot: {'question': 'What is Dart?', 'answer': 'A language'},
        conceptName: 'Dart',
        createdAt: '2025-06-01T00:00:00.000Z',
        status: ChallengeStatus.pending,
      );

      final json = challenge.toJson();
      final restored = Challenge.fromJson(json);

      expect(restored.id, 'c1');
      expect(restored.fromUid, 'user1');
      expect(restored.conceptName, 'Dart');
      expect(restored.status, ChallengeStatus.pending);
    });

    test('withStatus creates new instance', () {
      const challenge = Challenge(
        id: 'c1',
        fromUid: 'user1',
        fromName: 'Alice',
        toUid: 'user2',
        quizItemSnapshot: {},
        conceptName: 'Dart',
        createdAt: '2025-06-01T00:00:00.000Z',
      );

      final accepted = challenge.withStatus(ChallengeStatus.accepted);
      expect(accepted.status, ChallengeStatus.accepted);
      expect(challenge.status, ChallengeStatus.pending); // original unchanged
    });

    test('withStatus includes score', () {
      const challenge = Challenge(
        id: 'c1',
        fromUid: 'user1',
        fromName: 'Alice',
        toUid: 'user2',
        quizItemSnapshot: {},
        conceptName: 'Dart',
        createdAt: '2025-06-01T00:00:00.000Z',
      );

      final completed =
          challenge.withStatus(ChallengeStatus.completed, score: 4);
      expect(completed.score, 4);
    });
  });

  group('Nudge', () {
    test('fromJson/toJson round-trip', () {
      const nudge = Nudge(
        id: 'n1',
        fromUid: 'user1',
        fromName: 'Alice',
        toUid: 'user2',
        conceptName: 'Docker',
        message: 'Time to review!',
        createdAt: '2025-06-01T00:00:00.000Z',
        status: NudgeStatus.pending,
      );

      final json = nudge.toJson();
      final restored = Nudge.fromJson(json);

      expect(restored.id, 'n1');
      expect(restored.conceptName, 'Docker');
      expect(restored.message, 'Time to review!');
      expect(restored.status, NudgeStatus.pending);
    });

    test('withStatus creates new instance', () {
      const nudge = Nudge(
        id: 'n1',
        fromUid: 'user1',
        fromName: 'Alice',
        toUid: 'user2',
        conceptName: 'Docker',
        createdAt: '2025-06-01T00:00:00.000Z',
      );

      final seen = nudge.withStatus(NudgeStatus.seen);
      expect(seen.status, NudgeStatus.seen);
      expect(nudge.status, NudgeStatus.pending); // original unchanged
    });

    test('fromJson handles null message', () {
      final nudge = Nudge.fromJson(const {
        'id': 'n1',
        'fromUid': 'user1',
        'fromName': 'Alice',
        'toUid': 'user2',
        'conceptName': 'K8s',
        'createdAt': '2025-06-01T00:00:00.000Z',
        'status': 'pending',
      });

      expect(nudge.message, isNull);
    });
  });
}
