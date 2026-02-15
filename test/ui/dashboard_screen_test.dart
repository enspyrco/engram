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

    testWidgets('shows compact stats bar when graph has data', (tester) async {
      final graph = KnowledgeGraph(
        concepts: [
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
            question: 'What is Docker?',
            answer: 'A container runtime',
          ),
        ],
      );

      await tester.pumpWidget(buildApp(graph));
      await tester.pumpAndSettle();

      // Compact stats bar shows concept count (2) in the bottom bar
      expect(find.text('2'), findsOneWidget); // concept count
      // Info button is visible for opening full stats
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('info button opens bottom sheet with full stats',
        (tester) async {
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

      await tester.pumpWidget(buildApp(graph));
      await tester.pumpAndSettle();

      // Tap info button to open bottom sheet
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      // Stat cards near top of bottom sheet should be visible immediately
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Concepts'), findsOneWidget);

      // Scroll down within the bottom sheet to find Graph Status
      await tester.scrollUntilVisible(
        find.text('Graph Status'),
        50,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Graph Status'), findsOneWidget);
      expect(find.text('Due for review'), findsOneWidget);
    });
  });
}

class _PreloadedGraphNotifier extends KnowledgeGraphNotifier {
  _PreloadedGraphNotifier(this._graph);
  final KnowledgeGraph _graph;

  @override
  Future<KnowledgeGraph> build() async => _graph;
}
