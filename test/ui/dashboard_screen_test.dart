import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/network_health.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:engram/src/providers/knowledge_graph_provider.dart';
import 'package:engram/src/providers/network_health_provider.dart';
import 'package:engram/src/ui/screens/dashboard_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildApp(KnowledgeGraph graph) {
    return ProviderScope(
      overrides: [
        knowledgeGraphProvider.overrideWith(
          () => _PreloadedGraphNotifier(graph),
        ),
        // Override health to healthy so catastrophe animations don't block
        // pumpAndSettle. These tests verify dashboard stats, not catastrophe UI.
        networkHealthProvider.overrideWithValue(
          const NetworkHealth(score: 1.0, tier: HealthTier.healthy),
        ),
      ],
      // NoSplash avoids loading the ink_sparkle fragment shader, which the
      // widget-test harness cannot decode. Tapping the InkWell-based panel
      // toggle would otherwise throw.
      child: MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: const DashboardScreen(),
      ),
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

      // Insights panel shows concept count (2) in the collapsed summary row
      expect(find.text('2'), findsOneWidget); // concept count
      // The Details toggle is visible for expanding the full feature cards
      expect(find.text('Details'), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
    });

    testWidgets('Details toggle expands the insights panel inline', (
      tester,
    ) async {
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

      // Tap the Details toggle to expand the panel inline
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      // Stat cards in the expanded detail should be visible immediately
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Concepts'), findsOneWidget);

      // Scroll down within the expanded detail to find Graph Status
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
