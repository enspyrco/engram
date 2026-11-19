import 'package:engram/src/engine/fsrs_engine.dart';
import 'package:engram/src/ui/widgets/swipeable_quiz_card.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper to pump the swipeable card in a constrained layout.
Future<void> _pumpCard(
  WidgetTester tester, {
  required ValueChanged<FsrsRating> onRate,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 300,
            child: SwipeableQuizCard(
              onRate: onRate,
              child: const Card(child: Center(child: Text('Test question'))),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('SwipeableQuizCard', () {
    group('rating from swipe direction and velocity', () {
      testWidgets('swipe left fires FsrsRating.again', (tester) async {
        FsrsRating? received;
        await _pumpCard(tester, onRate: (r) => received = r);

        // Swipe left past the minimum displacement threshold.
        await tester.fling(
          find.byType(SwipeableQuizCard),
          const Offset(-200, 0),
          800,
        );
        await tester.pumpAndSettle();

        expect(received, FsrsRating.again);
      });

      testWidgets('gentle right swipe fires FsrsRating.hard', (tester) async {
        FsrsRating? received;
        await _pumpCard(tester, onRate: (r) => received = r);

        // Slow right swipe — velocity < 500 px/s.
        final center = tester.getCenter(find.byType(SwipeableQuizCard));
        final gesture = await tester.startGesture(center);
        // Move slowly in small increments to keep velocity low.
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(10, 0));
          await tester.pump(const Duration(milliseconds: 50));
        }
        await gesture.up();
        await tester.pumpAndSettle();

        expect(received, FsrsRating.hard);
      });

      testWidgets('confident right swipe fires FsrsRating.good', (
        tester,
      ) async {
        FsrsRating? received;
        await _pumpCard(tester, onRate: (r) => received = r);

        // Medium velocity fling — 1000 px/s (between 500 and 1500).
        await tester.fling(
          find.byType(SwipeableQuizCard),
          const Offset(200, 0),
          1000,
        );
        await tester.pumpAndSettle();

        expect(received, FsrsRating.good);
      });

      testWidgets('fling right fires FsrsRating.easy', (tester) async {
        FsrsRating? received;
        await _pumpCard(tester, onRate: (r) => received = r);

        // Fast fling — 2000 px/s (≥ 1500).
        await tester.fling(
          find.byType(SwipeableQuizCard),
          const Offset(200, 0),
          2000,
        );
        await tester.pumpAndSettle();

        expect(received, FsrsRating.easy);
      });
    });

    group('insufficient drag', () {
      testWidgets('small drag snaps back without firing callback', (
        tester,
      ) async {
        FsrsRating? received;
        await _pumpCard(tester, onRate: (r) => received = r);

        // Drag only 20px — well below 15% of 400px = 60px threshold.
        final center = tester.getCenter(find.byType(SwipeableQuizCard));
        final gesture = await tester.startGesture(center);
        await gesture.moveBy(const Offset(20, 0));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(received, isNull);
      });
    });

    group('visual feedback', () {
      testWidgets('card rotates during horizontal drag', (tester) async {
        await _pumpCard(tester, onRate: (_) {});

        final center = tester.getCenter(find.byType(SwipeableQuizCard));
        final gesture = await tester.startGesture(center);
        await gesture.moveBy(const Offset(100, 0));
        await tester.pump();

        // Find the Transform inside SwipeableQuizCard (not other Transforms in
        // the widget tree). The one we want has a non-identity rotation.
        final transforms = tester.widgetList<Transform>(find.byType(Transform));
        final hasRotatedTransform = transforms.any(
          (t) => t.transform.storage[1] != 0.0,
        );
        expect(hasRotatedTransform, isTrue);

        await gesture.up();
        await tester.pumpAndSettle();
      });

      testWidgets('color overlay appears on left drag', (tester) async {
        await _pumpCard(tester, onRate: (_) {});

        final center = tester.getCenter(find.byType(SwipeableQuizCard));
        final gesture = await tester.startGesture(center);
        await gesture.moveBy(const Offset(-100, 0));
        await tester.pump();

        // A red-tinted overlay should be visible.
        final containers = tester.widgetList<Container>(find.byType(Container));
        final hasRedOverlay = containers.any((c) {
          final decoration = c.decoration;
          if (decoration is BoxDecoration && decoration.color != null) {
            return (decoration.color!.r * 255).round() > 200 &&
                decoration.color!.a > 0.0;
          }
          return false;
        });
        expect(hasRedOverlay, isTrue);

        await gesture.up();
        await tester.pumpAndSettle();
      });

      testWidgets('rating label shows during drag past threshold', (
        tester,
      ) async {
        await _pumpCard(tester, onRate: (_) {});

        final center = tester.getCenter(find.byType(SwipeableQuizCard));
        final gesture = await tester.startGesture(center);
        // Drag past minimum threshold (15% of 400 = 60px).
        await gesture.moveBy(const Offset(-100, 0));
        await tester.pump();

        expect(find.text('Again'), findsOneWidget);

        await gesture.up();
        await tester.pumpAndSettle();
      });

      testWidgets('right drag label changes with displacement', (tester) async {
        await _pumpCard(tester, onRate: (_) {});

        final center = tester.getCenter(find.byType(SwipeableQuizCard));
        final gesture = await tester.startGesture(center);

        // Small right drag (80/400 = 20%) → Hard.
        await gesture.moveBy(const Offset(80, 0));
        await tester.pump();
        expect(find.text('Hard'), findsOneWidget);

        // Medium right drag (140/400 = 35%) → Good.
        await gesture.moveBy(const Offset(60, 0));
        await tester.pump();
        expect(find.text('Good'), findsOneWidget);

        // Large right drag (200/400 = 50%) → Easy.
        await gesture.moveBy(const Offset(60, 0));
        await tester.pump();
        expect(find.text('Easy'), findsOneWidget);

        await gesture.up();
        await tester.pumpAndSettle();
      });
    });

    group('disabled state', () {
      testWidgets('does not respond to swipe when enabled is false', (
        tester,
      ) async {
        FsrsRating? received;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  height: 300,
                  child: SwipeableQuizCard(
                    onRate: (r) => received = r,
                    enabled: false,
                    child: const Card(
                      child: Center(child: Text('Test question')),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.fling(
          find.byType(SwipeableQuizCard),
          const Offset(-200, 0),
          800,
        );
        await tester.pumpAndSettle();

        expect(received, isNull);
      });
    });
  });
}
