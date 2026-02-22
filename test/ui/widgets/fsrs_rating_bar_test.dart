import 'package:engram/src/engine/fsrs_engine.dart';
import 'package:engram/src/ui/widgets/fsrs_rating_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FsrsRatingBar', () {
    testWidgets('renders 4 rating buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FsrsRatingBar(onRate: (_) {}),
          ),
        ),
      );

      expect(find.text('Again'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Rate your recall:'), findsOneWidget);
    });

    testWidgets('tapping Again fires FsrsRating.again', (tester) async {
      FsrsRating? received;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FsrsRatingBar(onRate: (r) => received = r),
          ),
        ),
      );

      await tester.tap(find.text('Again'));
      expect(received, FsrsRating.again);
    });

    testWidgets('tapping Hard fires FsrsRating.hard', (tester) async {
      FsrsRating? received;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FsrsRatingBar(onRate: (r) => received = r),
          ),
        ),
      );

      await tester.tap(find.text('Hard'));
      expect(received, FsrsRating.hard);
    });

    testWidgets('tapping Good fires FsrsRating.good', (tester) async {
      FsrsRating? received;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FsrsRatingBar(onRate: (r) => received = r),
          ),
        ),
      );

      await tester.tap(find.text('Good'));
      expect(received, FsrsRating.good);
    });

    testWidgets('tapping Easy fires FsrsRating.easy', (tester) async {
      FsrsRating? received;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FsrsRatingBar(onRate: (r) => received = r),
          ),
        ),
      );

      await tester.tap(find.text('Easy'));
      expect(received, FsrsRating.easy);
    });
  });
}
