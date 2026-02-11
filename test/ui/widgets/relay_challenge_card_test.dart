import 'package:engram/src/models/relay_challenge.dart';
import 'package:engram/src/ui/widgets/relay_challenge_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RelayChallengeCard', () {
    late RelayChallenge relay;

    setUp(() {
      relay = RelayChallenge(
        id: 'relay_1',
        title: 'CI/CD Pipeline',
        legs: [
          const RelayLeg(
            conceptId: 'c1',
            conceptName: 'Git Basics',
            claimedByUid: 'u1',
            claimedByName: 'Alice',
            claimedAt: '2025-06-15T10:00:00.000Z',
            completedAt: '2025-06-15T12:00:00.000Z',
          ),
          const RelayLeg(conceptId: 'c2', conceptName: 'Branching'),
          const RelayLeg(conceptId: 'c3', conceptName: 'CI Pipelines'),
        ],
        createdAt: '2025-06-14T00:00:00.000Z',
        createdByUid: 'creator1',
      );
    });

    testWidgets('displays title and progress count', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelayChallengeCard(
              relay: relay,
              currentUid: 'u1',
            ),
          ),
        ),
      );

      expect(find.text('CI/CD Pipeline'), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('shows Claim button on claimable leg', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelayChallengeCard(
              relay: relay,
              currentUid: 'u2',
              onClaimLeg: (_) {},
            ),
          ),
        ),
      );

      // Leg 1 (index 1) should show Claim since leg 0 is completed
      expect(find.text('Claim'), findsOneWidget);
    });

    testWidgets('renders concept names', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelayChallengeCard(
              relay: relay,
              currentUid: 'u1',
            ),
          ),
        ),
      );

      expect(find.text('Git Basics'), findsOneWidget);
      expect(find.text('Branching'), findsOneWidget);
      expect(find.text('CI Pipelines'), findsOneWidget);
    });

    testWidgets('invokes onClaimLeg callback', (tester) async {
      int? claimedIndex;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelayChallengeCard(
              relay: relay,
              currentUid: 'u2',
              onClaimLeg: (index) => claimedIndex = index,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Claim'));
      expect(claimedIndex, 1); // Second leg is claimable
    });

    testWidgets('shows progress bar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelayChallengeCard(
              relay: relay,
              currentUid: 'u1',
            ),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });
}
