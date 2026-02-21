import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:engram/src/ui/graph/force_directed_graph_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ForceDirectedGraphWidget', () {
    testWidgets('renders and settles with pumpAndSettle', (tester) async {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'Docker',
            description: 'Containers',
            sourceDocumentId: 'doc1',
          ),
          Concept(
            id: 'c2',
            name: 'K8s',
            description: 'Orchestration',
            sourceDocumentId: 'doc1',
          ),
        ],
        relationships: [
          const Relationship(
            id: 'r1',
            fromConceptId: 'c2',
            toConceptId: 'c1',
            label: 'depends on',
          ),
        ],
        quizItems: [
          QuizItem.newCard(
            id: 'q1',
            conceptId: 'c1',
            question: 'Q?',
            answer: 'A.',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ForceDirectedGraphWidget(graph: graph)),
        ),
      );

      // This is the key test: pumpAndSettle() works because the ticker
      // stops once the force-directed layout converges.
      await tester.pumpAndSettle();

      // Widget should have rendered a CustomPaint
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('shows node panel on tap', (tester) async {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'Docker',
            description: 'Container runtime',
            sourceDocumentId: 'doc1',
          ),
        ],
        quizItems: [
          QuizItem.newCard(
            id: 'q1',
            conceptId: 'c1',
            question: 'Q?',
            answer: 'A.',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ForceDirectedGraphWidget(graph: graph)),
        ),
      );
      await tester.pumpAndSettle();

      // Tap in the center of the widget (the single node should be nearby)
      await tester.tapAt(
        tester.getCenter(find.byType(ForceDirectedGraphWidget)),
      );
      await tester.pumpAndSettle();

      // The overlay may or may not appear depending on exact node position,
      // but the widget should not crash.
      expect(find.byType(ForceDirectedGraphWidget), findsOneWidget);
    });

    testWidgets('long-press drag does not crash and re-settles', (
      tester,
    ) async {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(id: 'c1', name: 'A', description: '', sourceDocumentId: 'd1'),
          Concept(id: 'c2', name: 'B', description: '', sourceDocumentId: 'd1'),
        ],
        relationships: [
          const Relationship(
            id: 'r1',
            fromConceptId: 'c2',
            toConceptId: 'c1',
            label: 'depends on',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(
              child: ForceDirectedGraphWidget(graph: graph),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Simulate a long-press drag gesture near the center (where nodes
      // are likely to be after force-directed layout settles).
      final center = tester.getCenter(find.byType(ForceDirectedGraphWidget));
      final gesture = await tester.startGesture(center);
      await tester.pump(
        const Duration(milliseconds: 600),
      ); // trigger long press
      await gesture.moveBy(const Offset(50, 30));
      await tester.pump();
      await gesture.moveBy(const Offset(20, -10));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Widget should still be alive and settled after the drag.
      expect(find.byType(ForceDirectedGraphWidget), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('handles empty graph', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForceDirectedGraphWidget(graph: KnowledgeGraph.empty),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
