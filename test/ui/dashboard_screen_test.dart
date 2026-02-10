import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/network_health.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:engram/src/providers/knowledge_graph_provider.dart';
import 'package:engram/src/providers/network_health_provider.dart';
import 'package:engram/src/ui/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildApp(KnowledgeGraph graph) {
    return ProviderScope(
      overrides: [
        knowledgeGraphProvider.overrideWith(() => _PreloadedGraphNotifier(graph)),
        // Override health to healthy so catastrophe animations don't block
        // pumpAndSettle. These tests verify dashboard stats, not catastrophe UI.
        networkHealthProvider.overrideWithValue(
          const NetworkHealth(score: 1.0, tier: HealthTier.healthy),
        ),
      ],
      child: const MaterialApp(home: DashboardScreen()),
    );
  }

  group('DashboardScreen', () {
    testWidgets('shows empty state when no concepts', (tester) async {
      await tester.pumpWidget(buildApp(KnowledgeGraph.empty));
      await tester.pumpAndSettle();

      expect(find.text('No knowledge graph yet'), findsOneWidget);
    });

    testWidgets('shows stats when graph has data', (tester) async {
      final graph = KnowledgeGraph(
        concepts: const [
          Concept(
            id: 'c1',
            name: 'Docker',
            description: 'Container runtime',
            sourceDocumentId: 'doc1',
          ),
          Concept(
            id: 'c2',
            name: 'Kubernetes',
            description: 'Orchestrator',
            sourceDocumentId: 'doc1',
          ),
        ],
        relationships: const [
          Relationship(
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
            question: 'What is Docker?',
            answer: 'A container runtime',
          ),
        ],
      );

      await tester.pumpWidget(buildApp(graph));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget); // concepts
      expect(find.text('1'), findsAtLeast(1)); // relationships or quiz items
      expect(find.text('Mastery'), findsOneWidget);
    });

    testWidgets('shows graph status section', (tester) async {
      final graph = KnowledgeGraph(
        concepts: const [
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

      await tester.pumpWidget(buildApp(graph));
      await tester.pumpAndSettle();

      // Scroll down past the health indicator to reach Graph Status
      await tester.scrollUntilVisible(
        find.text('Graph Status'),
        50,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Graph Status'), findsOneWidget);
      expect(find.text('Due for review'), findsOneWidget);
      expect(find.text('Foundational'), findsOneWidget);
    });
  });
}

class _PreloadedGraphNotifier extends KnowledgeGraphNotifier {
  _PreloadedGraphNotifier(this._graph);
  final KnowledgeGraph _graph;

  @override
  Future<KnowledgeGraph> build() async => _graph;
}
