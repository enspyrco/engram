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
        concepts: [
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
        relationships: [
          const Relationship(
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

    testWidgets('team node positions preserved across graph rebuild',
        (tester) async {
      final graph1 = KnowledgeGraph(
        concepts: [
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
        relationships: [
          const Relationship(
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

      // Same team node instance persists across rebuilds (like in production).
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
              graph: graph1,
              teamNodes: teamNodes,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Set a known position on the team node (simulates a settled layout).
      // _buildGraph will read this via widget.teamNodes when the graph changes.
      const knownPosition = Offset(350, 250);
      teamNodes.first.position = knownPosition;

      // Add a new concept to trigger _buildGraph via didUpdateWidget.
      final graph2 = KnowledgeGraph(
        concepts: [
          ...graph1.concepts,
          Concept(
              id: 'c3',
              name: 'Helm',
              description: 'Package manager',
              sourceDocumentId: 'doc1'),
        ],
        relationships: [
          ...graph1.relationships,
          const Relationship(
              id: 'r2',
              fromConceptId: 'c3',
              toConceptId: 'c2',
              label: 'depends on'),
        ],
        quizItems: graph1.quizItems.toList(),
      );

      // Re-pump with updated graph — triggers didUpdateWidget → _buildGraph.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForceDirectedGraphWidget(
              graph: graph2,
              teamNodes: teamNodes,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Team node should be pinned at its old position.
      expect(
        (teamNodes.first.position - knownPosition).distance,
        lessThan(1.0),
        reason: 'Team node should stay pinned across graph rebuild',
      );
    });

    testWidgets('renders without team nodes (backward compatible)',
        (tester) async {
      final graph = KnowledgeGraph(
        concepts: [
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
