import 'package:engram/src/engine/force_directed_layout.dart';
import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:engram/src/ui/graph/force_directed_graph_widget.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

// ── Inline helpers ──────────────────────────────────────────────────────

/// Compute 0.97^n (for recovering initial temperature after n cooling steps).
double _pow097(int n) => math.pow(0.97, n).toDouble();

KnowledgeGraph makeGraph({
  int conceptCount = 3,
  bool withEdges = false,
  bool withQuizItems = false,
}) {
  return KnowledgeGraph(
    concepts: List.generate(
      conceptCount,
      (i) => Concept(
        id: 'c$i',
        name: 'Concept $i',
        description: 'Description $i',
        sourceDocumentId: 'doc1',
      ),
    ),
    relationships: withEdges
        ? List.generate(
            conceptCount - 1,
            (i) => Relationship(
              id: 'r$i',
              fromConceptId: 'c${i + 1}',
              toConceptId: 'c$i',
              label: 'relates to',
            ),
          )
        : [],
    quizItems: withQuizItems
        ? List.generate(
            conceptCount,
            (i) => QuizItem.newCard(
              id: 'q$i',
              conceptId: 'c$i',
              question: 'Question $i?',
              answer: 'Answer $i.',
            ),
          )
        : [],
  );
}

Widget wrapWidget(Widget widget) {
  return MaterialApp(home: Scaffold(body: widget));
}

void main() {
  group('Ticker lifecycle', () {
    testWidgets('ticker stops when layout settles (pumpAndSettle completes)',
        (tester) async {
      await tester.pumpWidget(wrapWidget(
        ForceDirectedGraphWidget(
          graph: makeGraph(conceptCount: 3, withEdges: true),
        ),
      ));

      // pumpAndSettle completes because the ticker stops once settled
      await tester.pumpAndSettle();
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('ticker restarts when graph changes', (tester) async {
      final graph3 = makeGraph(conceptCount: 3, withEdges: true);

      await tester.pumpWidget(wrapWidget(
        ForceDirectedGraphWidget(graph: graph3),
      ));
      await tester.pumpAndSettle();

      // Update graph with an extra node
      final graph4 = makeGraph(conceptCount: 4, withEdges: true);
      var tickedAfterUpdate = false;

      await tester.pumpWidget(wrapWidget(
        ForceDirectedGraphWidget(
          graph: graph4,
          onDebugTick: (_, __, ___, ____) {
            tickedAfterUpdate = true;
          },
        ),
      ));
      await tester.pump(); // single frame triggers the restarted ticker

      expect(tickedAfterUpdate, isTrue);
      await tester.pumpAndSettle();
    });
  });

  group('onDebugTick callback', () {
    testWidgets('fires with decreasing temperature', (tester) async {
      final temps = <double>[];

      await tester.pumpWidget(wrapWidget(
        ForceDirectedGraphWidget(
          graph: makeGraph(conceptCount: 3, withEdges: true),
          onDebugTick: (temp, _, __, ___) => temps.add(temp),
        ),
      ));
      await tester.pumpAndSettle();

      expect(temps.length, greaterThan(2));
      for (var i = 1; i < temps.length; i++) {
        expect(temps[i], lessThan(temps[i - 1]),
            reason: 'tick $i: ${temps[i]} should be < ${temps[i - 1]}');
      }
    });

    testWidgets('reports correct pinned count after incremental update',
        (tester) async {
      final graph2 = makeGraph(conceptCount: 2, withEdges: true);

      await tester.pumpWidget(wrapWidget(
        ForceDirectedGraphWidget(graph: graph2),
      ));
      await tester.pumpAndSettle();

      // Update to 4 nodes — first 2 should be pinned as anchors
      final graph4 = makeGraph(conceptCount: 4, withEdges: true);
      int? reportedPinnedCount;

      await tester.pumpWidget(wrapWidget(
        ForceDirectedGraphWidget(
          graph: graph4,
          onDebugTick: (_, pinned, __, ___) {
            reportedPinnedCount ??= pinned;
          },
        ),
      ));
      await tester.pump();

      expect(reportedPinnedCount, 2);
      await tester.pumpAndSettle();
    });

    testWidgets('reports isSettled=true on final tick', (tester) async {
      final ticks = <(double temp, bool settled)>[];

      await tester.pumpWidget(wrapWidget(
        ForceDirectedGraphWidget(
          graph: makeGraph(conceptCount: 3, withEdges: true),
          onDebugTick: (temp, _, __, settled) {
            ticks.add((temp, settled));
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(ticks, isNotEmpty);
      expect(ticks.last.$2, isTrue, reason: 'final tick should report settled');
    });

    testWidgets('reports correct totalCount', (tester) async {
      int? reportedTotal;

      await tester.pumpWidget(wrapWidget(
        ForceDirectedGraphWidget(
          graph: makeGraph(conceptCount: 3),
          onDebugTick: (_, __, total, ___) {
            reportedTotal ??= total;
          },
        ),
      ));
      await tester.pump();

      expect(reportedTotal, 3);
      await tester.pumpAndSettle();
    });
  });

  group('Layout dimensions', () {
    testWidgets('default layout size is 800x600', (tester) async {
      double? firstTemp;

      await tester.pumpWidget(wrapWidget(
        ForceDirectedGraphWidget(
          graph: makeGraph(conceptCount: 3, withEdges: true),
          onDebugTick: (temp, _, __, ___) {
            firstTemp ??= temp;
          },
        ),
      ));
      await tester.pump();

      // After pre-settle (60 steps) + first tick, recover initial temp.
      // Initial = min(800,600)/6 = 100, after 61 cooling steps: 100 * 0.97^61
      final initialTemp = firstTemp! / _pow097(61);
      expect(initialTemp, closeTo(100.0, 0.5));
      await tester.pumpAndSettle();
    });

    testWidgets('custom dimensions applied', (tester) async {
      double? firstTemp;

      await tester.pumpWidget(wrapWidget(
        ForceDirectedGraphWidget(
          graph: makeGraph(conceptCount: 3, withEdges: true),
          layoutWidth: 1200,
          layoutHeight: 900,
          onDebugTick: (temp, _, __, ___) {
            firstTemp ??= temp;
          },
        ),
      ));
      await tester.pump();

      // Initial = min(1200,900)/6 = 150, after 61 cooling steps
      final initialTemp = firstTemp! / _pow097(61);
      expect(initialTemp, closeTo(150.0, 0.5));
      await tester.pumpAndSettle();
    });
  });

  group('Graph updates', () {
    testWidgets('adding a node does not crash', (tester) async {
      final graph3 = makeGraph(conceptCount: 3, withEdges: true);
      await tester.pumpWidget(wrapWidget(
        ForceDirectedGraphWidget(graph: graph3),
      ));
      await tester.pumpAndSettle();

      final graph4 = makeGraph(conceptCount: 4, withEdges: true);
      await tester.pumpWidget(wrapWidget(
        ForceDirectedGraphWidget(graph: graph4),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ForceDirectedGraphWidget), findsOneWidget);
    });

    testWidgets('removing a node does not crash', (tester) async {
      final graph3 = makeGraph(conceptCount: 3, withEdges: true);
      await tester.pumpWidget(wrapWidget(
        ForceDirectedGraphWidget(graph: graph3),
      ));
      await tester.pumpAndSettle();

      final graph2 = makeGraph(conceptCount: 2, withEdges: true);
      await tester.pumpWidget(wrapWidget(
        ForceDirectedGraphWidget(graph: graph2),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ForceDirectedGraphWidget), findsOneWidget);
    });

    testWidgets('empty graph renders', (tester) async {
      await tester.pumpWidget(wrapWidget(
        ForceDirectedGraphWidget(graph: KnowledgeGraph.empty),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('Tap interaction', () {
    // Use layout dimensions larger than the auto-scaling threshold
    // (sqrt(nodeCount) * 120) so the seed layout matches the widget's layout.
    const testLayoutSize = 200.0;

    testWidgets('tapping a node shows overlay with concept name',
        (tester) async {
      // Compute where the node will settle — widget uses seed 42 internally
      // and runs 60 pre-settle steps with gravity before first paint.
      final seedLayout = ForceDirectedLayout(
        nodeCount: 1,
        edges: [],
        width: testLayoutSize,
        height: testLayoutSize,
        seed: 42,
      );
      for (var i = 0; i < 60; i++) {
        if (!seedLayout.step()) break;
      }
      final nodePos = seedLayout.positions[0];

      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c0',
            name: 'TestConcept',
            description: 'A test concept',
            sourceDocumentId: 'doc1',
          ),
        ],
        quizItems: [
          QuizItem.newCard(
            id: 'q0',
            conceptId: 'c0',
            question: 'Q?',
            answer: 'A.',
          ),
        ],
      );

      await tester.pumpWidget(wrapWidget(
        ForceDirectedGraphWidget(
          graph: graph,
          layoutWidth: testLayoutSize,
          layoutHeight: testLayoutSize,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap at the node's layout position (relative to widget top-left).
      // With identity transform, localPosition matches content coordinates.
      final widgetTopLeft =
          tester.getTopLeft(find.byType(ForceDirectedGraphWidget));
      await tester.tapAt(widgetTopLeft + nodePos);
      // DoubleTapRecognizer delays single-tap by kDoubleTapTimeout (300ms).
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Overlay card shows the concept name
      expect(find.text('TestConcept'), findsOneWidget);
    });

    testWidgets('tapping empty space dismisses overlay', (tester) async {
      final seedLayout = ForceDirectedLayout(
        nodeCount: 1,
        edges: [],
        width: testLayoutSize,
        height: testLayoutSize,
        seed: 42,
      );
      for (var i = 0; i < 60; i++) {
        if (!seedLayout.step()) break;
      }
      final nodePos = seedLayout.positions[0];

      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c0',
            name: 'TestConcept',
            description: 'A test concept',
            sourceDocumentId: 'doc1',
          ),
        ],
        quizItems: [
          QuizItem.newCard(
            id: 'q0',
            conceptId: 'c0',
            question: 'Q?',
            answer: 'A.',
          ),
        ],
      );

      await tester.pumpWidget(wrapWidget(
        ForceDirectedGraphWidget(
          graph: graph,
          layoutWidth: testLayoutSize,
          layoutHeight: testLayoutSize,
        ),
      ));
      await tester.pumpAndSettle();

      // First, show the overlay by tapping the node
      final widgetTopLeft =
          tester.getTopLeft(find.byType(ForceDirectedGraphWidget));
      await tester.tapAt(widgetTopLeft + nodePos);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('TestConcept'), findsOneWidget);

      // Now tap empty space (top-left corner, far from node near center)
      await tester.tapAt(widgetTopLeft + const Offset(5, 5));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('TestConcept'), findsNothing);
    });
  });
}
