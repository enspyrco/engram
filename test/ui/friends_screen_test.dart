import 'package:engram/src/models/challenge.dart';
import 'package:engram/src/models/friend.dart';
import 'package:engram/src/models/mastery_snapshot.dart';
import 'package:engram/src/models/nudge.dart';
import 'package:engram/src/providers/auth_provider.dart';
import 'package:engram/src/providers/challenge_provider.dart';
import 'package:engram/src/providers/friends_provider.dart';
import 'package:engram/src/providers/nudge_provider.dart';
import 'package:engram/src/ui/screens/friends_screen.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _PreloadedFriendsNotifier extends FriendsNotifier {
  _PreloadedFriendsNotifier(this._friends);
  final List<Friend> _friends;

  @override
  Future<List<Friend>> build() async => _friends;
}

class _PreloadedChallengeNotifier extends ChallengeNotifier {
  _PreloadedChallengeNotifier(this._challenges);
  final List<Challenge> _challenges;

  @override
  Stream<List<Challenge>> build() => Stream.value(_challenges);
}

class _PreloadedNudgeNotifier extends NudgeNotifier {
  _PreloadedNudgeNotifier(this._nudges);
  final List<Nudge> _nudges;

  @override
  Stream<List<Nudge>> build() => Stream.value(_nudges);
}

void main() {
  group('FriendsScreen', () {
    late MockFirebaseAuth mockAuth;

    setUp(() {
      mockAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user1', displayName: 'Alice'),
      );
    });

    Widget buildApp({
      List<Friend> friends = const [],
      List<Challenge> challenges = const [],
      List<Nudge> nudges = const [],
    }) {
      return ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          friendsProvider
              .overrideWith(() => _PreloadedFriendsNotifier(friends)),
          challengeProvider
              .overrideWith(() => _PreloadedChallengeNotifier(challenges)),
          nudgeProvider
              .overrideWith(() => _PreloadedNudgeNotifier(nudges)),
        ],
        child: const MaterialApp(home: FriendsScreen()),
      );
    }

    testWidgets('shows empty state when no friends', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      expect(find.text('No friends yet'), findsOneWidget);
      expect(
        find.text(
            'Friends using the same Outline wiki will appear here automatically.'),
        findsOneWidget,
      );
    });

    testWidgets('shows friend cards', (tester) async {
      await tester.pumpWidget(buildApp(
        friends: [
          const Friend(
            uid: 'user2',
            displayName: 'Bob',
            masterySnapshot: MasterySnapshot(
              totalConcepts: 20,
              mastered: 10,
              learning: 5,
              newCount: 5,
              streak: 3,
            ),
          ),
        ],
      ));
      await tester.pump();

      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('10/20'), findsOneWidget);
      expect(find.text('3-day streak'), findsOneWidget);
    });

    testWidgets('shows incoming challenge card', (tester) async {
      await tester.pumpWidget(buildApp(
        friends: [
          const Friend(uid: 'user2', displayName: 'Bob'),
        ],
        challenges: [
          const Challenge(
            id: 'c1',
            fromUid: 'user2',
            fromName: 'Bob',
            toUid: 'user1',
            quizItemSnapshot: {},
            conceptName: 'Dart basics',
            createdAt: '2025-06-01T00:00:00.000Z',
          ),
        ],
      ));
      await tester.pump();

      expect(find.text('Bob challenges you!'), findsOneWidget);
      expect(find.text('Topic: Dart basics'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
    });

    testWidgets('shows incoming nudge card', (tester) async {
      await tester.pumpWidget(buildApp(
        friends: [
          const Friend(uid: 'user2', displayName: 'Bob'),
        ],
        nudges: [
          const Nudge(
            id: 'n1',
            fromUid: 'user2',
            fromName: 'Bob',
            toUid: 'user1',
            conceptName: 'Kubernetes',
            message: 'Hey, review this!',
            createdAt: '2025-06-01T00:00:00.000Z',
          ),
        ],
      ));
      await tester.pump();

      expect(
        find.text('Bob nudged you about Kubernetes!'),
        findsOneWidget,
      );
      expect(find.text('"Hey, review this!"'), findsOneWidget);
      expect(find.text('Review now'), findsOneWidget);
    });
  });
}
