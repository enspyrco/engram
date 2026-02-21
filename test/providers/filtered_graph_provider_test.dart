import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/document_metadata.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:engram/src/providers/collection_filter_provider.dart';
import 'package:engram/src/providers/filtered_graph_provider.dart';
import 'package:engram/src/providers/knowledge_graph_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A graph spanning two collections for testing filter behavior.
KnowledgeGraph _twoCollectionGraph() {
  return KnowledgeGraph(
    concepts: [
      Concept(
        id: 'c1',
        name: 'Docker',
        description: '',
        sourceDocumentId: 'd1',
      ),
      Concept(id: 'c2', name: 'K8s', description: '', sourceDocumentId: 'd1'),
      Concept(id: 'c3', name: 'React', description: '', sourceDocumentId: 'd2'),
    ],
    relationships: [
      // Both endpoints in collection A
      const Relationship(
        id: 'r1',
        fromConceptId: 'c2',
        toConceptId: 'c1',
        label: 'depends on',
      ),
      // Cross-collection: c2 (colA) → c3 (colB) — should be excluded by either filter
      const Relationship(
        id: 'r2',
        fromConceptId: 'c2',
        toConceptId: 'c3',
        label: 'relates to',
      ),
    ],
    quizItems: [
      QuizItem.newCard(id: 'q1', conceptId: 'c1', question: 'Q1', answer: 'A1'),
      QuizItem.newCard(id: 'q2', conceptId: 'c3', question: 'Q2', answer: 'A2'),
    ],
    documentMetadata: [
      DocumentMetadata(
        documentId: 'd1',
        title: 'DevOps',
        updatedAt: '2026-01-01',
        ingestedAt: DateTime.utc(2026),
        collectionId: 'colA',
        collectionName: 'Infrastructure',
      ),
      DocumentMetadata(
        documentId: 'd2',
        title: 'Frontend',
        updatedAt: '2026-01-01',
        ingestedAt: DateTime.utc(2026),
        collectionId: 'colB',
        collectionName: 'Web',
      ),
    ],
  );
}

void main() {
  ProviderContainer buildContainer(
    KnowledgeGraph graph, {
    String? collectionId,
  }) {
    return ProviderContainer(
      overrides: [
        knowledgeGraphProvider.overrideWith(
          () => _PreloadedGraphNotifier(graph),
        ),
        if (collectionId != null)
          selectedCollectionIdProvider.overrideWith((ref) => collectionId),
      ],
    );
  }

  group('filteredGraphProvider', () {
    test('returns full graph when no collection selected', () async {
      final graph = _twoCollectionGraph();
      final container = buildContainer(graph);
      // Wait for the async notifier to resolve.
      await container.read(knowledgeGraphProvider.future);

      final filtered = container.read(filteredGraphProvider);
      expect(filtered, isNotNull);
      expect(filtered!.concepts.length, 3);
      expect(filtered.relationships.length, 2);
      expect(filtered.quizItems.length, 2);
    });

    test('filters to selected collection', () async {
      final graph = _twoCollectionGraph();
      final container = buildContainer(graph, collectionId: 'colA');
      await container.read(knowledgeGraphProvider.future);

      final filtered = container.read(filteredGraphProvider);
      expect(filtered, isNotNull);
      expect(filtered!.concepts.length, 2); // Docker, K8s
      expect(filtered.concepts.map((c) => c.name).toSet(), {'Docker', 'K8s'});
    });

    test('excludes cross-collection relationships', () async {
      final graph = _twoCollectionGraph();
      final container = buildContainer(graph, collectionId: 'colA');
      await container.read(knowledgeGraphProvider.future);

      final filtered = container.read(filteredGraphProvider)!;
      // Only r1 (both endpoints in colA) should survive; r2 is cross-collection.
      expect(filtered.relationships.length, 1);
      expect(filtered.relationships.first.id, 'r1');
    });

    test('filters quiz items to collection concepts', () async {
      final graph = _twoCollectionGraph();
      final container = buildContainer(graph, collectionId: 'colB');
      await container.read(knowledgeGraphProvider.future);

      final filtered = container.read(filteredGraphProvider)!;
      expect(filtered.quizItems.length, 1);
      expect(filtered.quizItems.first.conceptId, 'c3');
    });

    test('filters document metadata to collection', () async {
      final graph = _twoCollectionGraph();
      final container = buildContainer(graph, collectionId: 'colA');
      await container.read(knowledgeGraphProvider.future);

      final filtered = container.read(filteredGraphProvider)!;
      expect(filtered.documentMetadata.length, 1);
      expect(filtered.documentMetadata.first.title, 'DevOps');
    });

    test('returns empty graph for non-existent collection', () async {
      final graph = _twoCollectionGraph();
      final container = buildContainer(graph, collectionId: 'colZ');
      await container.read(knowledgeGraphProvider.future);

      final filtered = container.read(filteredGraphProvider)!;
      expect(filtered.concepts.length, 0);
      expect(filtered.relationships.length, 0);
      expect(filtered.quizItems.length, 0);
    });

    test('returns null when graph is null', () {
      final container = ProviderContainer(
        overrides: [
          knowledgeGraphProvider.overrideWith(
            () => _PreloadedGraphNotifier(null),
          ),
        ],
      );

      final filtered = container.read(filteredGraphProvider);
      expect(filtered, isNull);
    });
  });

  group('filteredStatsProvider', () {
    test('returns zero stats when graph is null', () {
      final container = ProviderContainer(
        overrides: [
          knowledgeGraphProvider.overrideWith(
            () => _PreloadedGraphNotifier(null),
          ),
        ],
      );

      final stats = container.read(filteredStatsProvider);
      expect(stats.concepts, 0);
      expect(stats.mastered, 0);
      expect(stats.due, 0);
    });

    test('computes stats from filtered graph', () async {
      final graph = _twoCollectionGraph();
      final container = buildContainer(graph, collectionId: 'colA');
      await container.read(knowledgeGraphProvider.future);

      final stats = container.read(filteredStatsProvider);
      expect(stats.concepts, 2); // Docker, K8s
      expect(stats.due, greaterThanOrEqualTo(0));
    });
  });
}

class _PreloadedGraphNotifier extends KnowledgeGraphNotifier {
  _PreloadedGraphNotifier(this._graph);
  final KnowledgeGraph? _graph;

  @override
  Future<KnowledgeGraph> build() async {
    if (_graph == null) throw StateError('No graph');
    return _graph;
  }
}
