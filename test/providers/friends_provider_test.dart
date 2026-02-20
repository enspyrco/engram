import 'package:engram/src/models/challenge.dart';
import 'package:engram/src/models/friend.dart';
import 'package:engram/src/models/nudge.dart';
import 'package:engram/src/storage/social_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:test/test.dart';

void main() {
  group('SocialRepository', () {
    late FakeFirebaseFirestore firestore;
    late SocialRepository repo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repo = SocialRepository(firestore: firestore, userId: 'user1');
    });

    group('wiki groups', () {
      test('joinWikiGroup writes member doc', () async {
        await repo.joinWikiGroup(
          wikiUrlHash: 'abc123',
          displayName: 'Alice',
          photoUrl: 'https://photo.url/alice.jpg',
        );

        final doc = await firestore
            .collection('wikiGroups')
            .doc('abc123')
            .collection('members')
            .doc('user1')
            .get();

        expect(doc.exists, isTrue);
        expect(doc.data()!['displayName'], 'Alice');
        expect(doc.data()!['uid'], 'user1');
      });

      test('watchWikiGroupMembers excludes self', () async {
        // Add self
        await repo.joinWikiGroup(
          wikiUrlHash: 'abc123',
          displayName: 'Alice',
        );

        // Add another user directly
        await firestore
            .collection('wikiGroups')
            .doc('abc123')
            .collection('members')
            .doc('user2')
            .set({
          'uid': 'user2',
          'displayName': 'Bob',
          'photoUrl': null,
          'joinedAt': '2025-01-01T00:00:00.000Z',
        });

        final members =
            await repo.watchWikiGroupMembers('abc123').first;

        expect(members.length, 1);
        expect(members[0].uid, 'user2');
        expect(members[0].displayName, 'Bob');
      });
    });

    group('friends', () {
      test('addFriend and watchFriends', () async {
        const friend = Friend(
          uid: 'user2',
          displayName: 'Bob',
          photoUrl: 'https://photo.url/bob.jpg',
        );

        await repo.addFriend(friend);
        final friends = await repo.watchFriends().first;

        expect(friends.length, 1);
        expect(friends[0].uid, 'user2');
        expect(friends[0].displayName, 'Bob');
      });
    });

    group('challenges', () {
      test('sendChallenge writes to Firestore', () async {
        const challenge = Challenge(
          id: 'c1',
          fromUid: 'user1',
          fromName: 'Alice',
          toUid: 'user2',
          quizItemSnapshot: {'question': 'What is X?', 'answer': 'Y'},
          conceptName: 'Testing',
          createdAt: '2025-06-01T00:00:00.000Z',
        );

        await repo.sendChallenge(challenge);

        final doc = await firestore
            .collection('social')
            .doc('challenges')
            .collection('items')
            .doc('c1')
            .get();

        expect(doc.exists, isTrue);
        expect(doc.data()!['fromUid'], 'user1');
        expect(doc.data()!['conceptName'], 'Testing');
        expect(doc.data()!['status'], 'pending');
      });

      test('watchIncomingChallenges filters by toUid and pending', () async {
        // Challenge for user1 (should appear)
        await firestore
            .collection('social')
            .doc('challenges')
            .collection('items')
            .doc('c1')
            .set({
          'id': 'c1',
          'fromUid': 'user2',
          'fromName': 'Bob',
          'toUid': 'user1',
          'quizItemSnapshot': {},
          'conceptName': 'Dart',
          'createdAt': '2025-06-01T00:00:00.000Z',
          'status': 'pending',
        });

        // Challenge for someone else (should not appear)
        await firestore
            .collection('social')
            .doc('challenges')
            .collection('items')
            .doc('c2')
            .set({
          'id': 'c2',
          'fromUid': 'user1',
          'fromName': 'Alice',
          'toUid': 'user3',
          'quizItemSnapshot': {},
          'conceptName': 'Flutter',
          'createdAt': '2025-06-01T00:00:00.000Z',
          'status': 'pending',
        });

        final challenges = await repo.watchIncomingChallenges().first;

        expect(challenges.length, 1);
        expect(challenges[0].id, 'c1');
        expect(challenges[0].conceptName, 'Dart');
      });

      test('updateChallengeStatus changes status', () async {
        await firestore
            .collection('social')
            .doc('challenges')
            .collection('items')
            .doc('c1')
            .set({
          'id': 'c1',
          'fromUid': 'user2',
          'fromName': 'Bob',
          'toUid': 'user1',
          'quizItemSnapshot': {},
          'conceptName': 'Dart',
          'createdAt': '2025-06-01T00:00:00.000Z',
          'status': 'pending',
        });

        await repo.updateChallengeStatus('c1', ChallengeStatus.accepted);

        final doc = await firestore
            .collection('social')
            .doc('challenges')
            .collection('items')
            .doc('c1')
            .get();
        expect(doc.data()!['status'], 'accepted');
      });

      test('updateChallengeStatus with score', () async {
        await firestore
            .collection('social')
            .doc('challenges')
            .collection('items')
            .doc('c1')
            .set({
          'id': 'c1',
          'fromUid': 'user2',
          'fromName': 'Bob',
          'toUid': 'user1',
          'quizItemSnapshot': {},
          'conceptName': 'Dart',
          'createdAt': '2025-06-01T00:00:00.000Z',
          'status': 'accepted',
        });

        await repo.updateChallengeStatus(
          'c1',
          ChallengeStatus.completed,
          score: 4,
        );

        final doc = await firestore
            .collection('social')
            .doc('challenges')
            .collection('items')
            .doc('c1')
            .get();
        expect(doc.data()!['status'], 'completed');
        expect(doc.data()!['score'], 4);
      });
    });

    group('nudges', () {
      test('sendNudge writes to Firestore', () async {
        const nudge = Nudge(
          id: 'n1',
          fromUid: 'user1',
          fromName: 'Alice',
          toUid: 'user2',
          conceptName: 'Docker',
          message: 'Time to review!',
          createdAt: '2025-06-01T00:00:00.000Z',
        );

        await repo.sendNudge(nudge);

        final doc = await firestore
            .collection('social')
            .doc('nudges')
            .collection('items')
            .doc('n1')
            .get();

        expect(doc.exists, isTrue);
        expect(doc.data()!['conceptName'], 'Docker');
        expect(doc.data()!['message'], 'Time to review!');
        expect(doc.data()!['status'], 'pending');
      });

      test('watchIncomingNudges filters by toUid and pending', () async {
        await firestore
            .collection('social')
            .doc('nudges')
            .collection('items')
            .doc('n1')
            .set({
          'id': 'n1',
          'fromUid': 'user2',
          'fromName': 'Bob',
          'toUid': 'user1',
          'conceptName': 'K8s',
          'createdAt': '2025-06-01T00:00:00.000Z',
          'status': 'pending',
        });

        // Already seen nudge (should not appear)
        await firestore
            .collection('social')
            .doc('nudges')
            .collection('items')
            .doc('n2')
            .set({
          'id': 'n2',
          'fromUid': 'user2',
          'fromName': 'Bob',
          'toUid': 'user1',
          'conceptName': 'CI/CD',
          'createdAt': '2025-06-01T00:00:00.000Z',
          'status': 'seen',
        });

        final nudges = await repo.watchIncomingNudges().first;

        expect(nudges.length, 1);
        expect(nudges[0].conceptName, 'K8s');
      });

      test('markNudgeSeen updates status', () async {
        await firestore
            .collection('social')
            .doc('nudges')
            .collection('items')
            .doc('n1')
            .set({
          'id': 'n1',
          'fromUid': 'user2',
          'fromName': 'Bob',
          'toUid': 'user1',
          'conceptName': 'K8s',
          'createdAt': '2025-06-01T00:00:00.000Z',
          'status': 'pending',
        });

        await repo.markNudgeSeen('n1');

        final doc = await firestore
            .collection('social')
            .doc('nudges')
            .collection('items')
            .doc('n1')
            .get();
        expect(doc.data()!['status'], 'seen');
      });
    });
  });
}
