import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:engram/src/ui/graph/static_graph_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildWidget(KnowledgeGraph graph) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox.expand(
          child: StaticGraphWidget(graph: graph),
        ),
      ),
    );
  }

  group('StaticGraphWidget', () {
    testWidgets('shows empty message for empty graph', (tester) async {
      await tester.pumpWidget(buildWidget(KnowledgeGraph.empty));
      await tester.pumpAndSettle();

      expect(find.text('No concepts to display'), findsOneWidget);
    });

    testWidgets('renders CustomPaint for non-empty graph', (tester) async {
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
            question: 'What is Docker?',
            answer: 'A container runtime',
          ),
        ],
      );

      await tester.pumpWidget(buildWidget(graph));
      await tester.pumpAndSettle();

      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('No concepts to display'), findsNothing);
    });

    testWidgets('settles immediately (no ticker)', (tester) async {
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

      await tester.pumpWidget(buildWidget(graph));
      // pumpAndSettle should complete without timeout since there's no ticker.
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('tap on empty area does not crash', (tester) async {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(id: 'c1', name: 'A', description: '', sourceDocumentId: 'd1'),
        ],
      );

      await tester.pumpWidget(buildWidget(graph));
      await tester.pumpAndSettle();

      // Tap somewhere on the widget — should not throw.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    });
  });
}
