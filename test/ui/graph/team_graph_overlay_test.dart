import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/detailed_mastery_snapshot.dart';
import 'package:engram/src/models/friend.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/mastery_snapshot.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:engram/src/ui/graph/force_directed_graph_widget.dart';
import 'package:engram/src/ui/graph/team_node.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ForceDirectedGraphWidget with team nodes', () {
    testWidgets('settles with team nodes in simulation', (tester) async {
      final graph = KnowledgeGraph(
        concepts: const [
          Concept(
              id: 'c1',
              name: 'Docker',
              description: 'Containers',
              sourceDocumentId: 'doc1'),
          Concept(
              id: 'c2',
              name: 'K8s',
              description: 'Orchestration',
              sourceDocumentId: 'doc1'),
        ],
        relationships: const [
          Relationship(
              id: 'r1',
              fromConceptId: 'c2',
              toConceptId: 'c1',
              label: 'depends on'),
        ],
        quizItems: [
          QuizItem.newCard(
              id: 'q1', conceptId: 'c1', question: 'Q?', answer: 'A.'),
        ],
      );

      final teamNodes = [
        TeamNode(
          friend: const Friend(uid: 'u1', displayName: 'Alice'),
          detailedSnapshot: const DetailedMasterySnapshot(
            summary: MasterySnapshot(totalConcepts: 2, mastered: 1),
            conceptMastery: {'c1': 'mastered'},
          ),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForceDirectedGraphWidget(
              graph: graph,
              teamNodes: teamNodes,
            ),
          ),
        ),
      );

      // Key assertion: pumpAndSettle works even with team nodes in the sim
      await tester.pumpAndSettle();

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders without team nodes (backward compatible)',
        (tester) async {
      final graph = KnowledgeGraph(
        concepts: const [
          Concept(
              id: 'c1',
              name: 'Docker',
              description: 'Containers',
              sourceDocumentId: 'doc1'),
        ],
        quizItems: [
          QuizItem.newCard(
              id: 'q1', conceptId: 'c1', question: 'Q?', answer: 'A.'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForceDirectedGraphWidget(graph: graph),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ForceDirectedGraphWidget), findsOneWidget);
    });
  });
}
