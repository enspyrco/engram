import 'package:engram/src/models/entropy_storm.dart';
import 'package:engram/src/ui/widgets/entropy_storm_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EntropyStormCard', () {
    testWidgets('shows scheduled state with opt-in button', (tester) async {
      final storm = EntropyStorm(
        id: 'storm_1',
        scheduledStart: DateTime.now().toUtc().add(const Duration(hours: 24)),
        scheduledEnd: DateTime.now().toUtc().add(const Duration(hours: 72)),
        status: StormStatus.scheduled,
        participantUids: ['u1'],
        createdByUid: 'u1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntropyStormCard(
              storm: storm,
              currentUid: 'u2', // not yet opted in
              onOptIn: () {},
              onOptOut: () {},
            ),
          ),
        ),
      );

      expect(find.text('Storm Incoming'), findsOneWidget);
      expect(find.text('Opt In'), findsOneWidget);
      expect(find.text('1 opted in'), findsOneWidget);
    });

    testWidgets('shows opt-out when already participating', (tester) async {
      final storm = EntropyStorm(
        id: 'storm_1',
        scheduledStart: DateTime.now().toUtc().add(const Duration(hours: 24)),
        scheduledEnd: DateTime.now().toUtc().add(const Duration(hours: 72)),
        status: StormStatus.scheduled,
        participantUids: ['u1'],
        createdByUid: 'u1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntropyStormCard(
              storm: storm,
              currentUid: 'u1', // already opted in
              onOptIn: () {},
              onOptOut: () {},
            ),
          ),
        ),
      );

      expect(find.text('Opt Out'), findsOneWidget);
    });

    testWidgets('shows active state with threshold', (tester) async {
      final storm = EntropyStorm(
        id: 'storm_1',
        scheduledStart: DateTime.now().toUtc().subtract(
          const Duration(hours: 12),
        ),
        scheduledEnd: DateTime.now().toUtc().add(const Duration(hours: 36)),
        status: StormStatus.active,
        participantUids: ['u1', 'u2'],
        createdByUid: 'u1',
        lowestHealth: 0.72,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntropyStormCard(storm: storm, currentUid: 'u1'),
          ),
        ),
      );

      expect(find.text('Storm Active!'), findsOneWidget);
      expect(find.text('Threshold: 70%'), findsOneWidget);
      expect(find.text('Lowest: 72%'), findsOneWidget);
    });

    testWidgets('shows survived state', (tester) async {
      final storm = EntropyStorm(
        id: 'storm_1',
        scheduledStart: DateTime.utc(2025, 6, 15),
        scheduledEnd: DateTime.utc(2025, 6, 17),
        status: StormStatus.survived,
        participantUids: ['u1', 'u2'],
        createdByUid: 'u1',
        lowestHealth: 0.75,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntropyStormCard(storm: storm, currentUid: 'u1'),
          ),
        ),
      );

      expect(find.text('Storm Survived!'), findsOneWidget);
      expect(find.textContaining('+10 glory points'), findsOneWidget);
    });

    testWidgets('shows failed state', (tester) async {
      final storm = EntropyStorm(
        id: 'storm_1',
        scheduledStart: DateTime.utc(2025, 6, 15),
        scheduledEnd: DateTime.utc(2025, 6, 17),
        status: StormStatus.failed,
        participantUids: ['u1'],
        createdByUid: 'u1',
        lowestHealth: 0.55,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntropyStormCard(storm: storm, currentUid: 'u1'),
          ),
        ),
      );

      expect(find.text('Storm Failed'), findsOneWidget);
      expect(find.textContaining('Better luck next time'), findsOneWidget);
    });
  });
}
