import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/document_metadata.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:engram/src/storage/firestore_graph_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:test/test.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FirestoreGraphRepository repo;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repo = FirestoreGraphRepository(
      firestore: fakeFirestore,
      userId: 'test-user',
    );
  });

  KnowledgeGraph sampleGraph() {
    return KnowledgeGraph(
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
          description: 'Container orchestration',
          sourceDocumentId: 'doc1',
        ),
      ],
      relationships: [
        const Relationship(
          id: 'r1',
          fromConceptId: 'c1',
          toConceptId: 'c2',
          label: 'used by',
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
      documentMetadata: [
        DocumentMetadata(
          documentId: 'doc1',
          title: 'Container Guide',
          updatedAt: '2025-01-01T00:00:00.000Z',
          ingestedAt: DateTime.utc(2025, 1, 1, 12),
        ),
      ],
    );
  }

  group('FirestoreGraphRepository', () {
    test('load returns empty graph when no data exists', () async {
      final graph = await repo.load();
      expect(graph.concepts, isEmpty);
      expect(graph.relationships, isEmpty);
      expect(graph.quizItems, isEmpty);
      expect(graph.documentMetadata, isEmpty);
    });

    test('save and load round-trips', () async {
      final graph = sampleGraph();
      await repo.save(graph);

      final loaded = await repo.load();
      expect(loaded.concepts, hasLength(2));
      expect(loaded.concepts.first.id, 'c1');
      expect(loaded.relationships, hasLength(1));
      expect(loaded.quizItems, hasLength(1));
      expect(loaded.documentMetadata, hasLength(1));
    });

    test('save upserts and removes orphans', () async {
      // Save initial graph with 2 concepts
      await repo.save(sampleGraph());

      // Save smaller graph — c1/c2 become orphans, c3 is new
      final smallGraph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c3',
            name: 'Helm',
            description: 'Package manager',
            sourceDocumentId: 'doc2',
          ),
        ],
      );
      await repo.save(smallGraph);

      final loaded = await repo.load();
      expect(loaded.concepts, hasLength(1));
      expect(loaded.concepts.first.id, 'c3');
      expect(loaded.relationships, isEmpty);
    });

    test('save preserves existing docs that remain in graph', () async {
      await repo.save(sampleGraph());

      // Save graph with one concept replaced but one retained
      final updatedGraph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'Docker Updated',
            description: 'Container runtime v2',
            sourceDocumentId: 'doc1',
          ),
        ],
      );
      await repo.save(updatedGraph);

      final loaded = await repo.load();
      expect(loaded.concepts, hasLength(1));
      expect(loaded.concepts.first.name, 'Docker Updated');
    });

    test('updateQuizItem writes single document', () async {
      final graph = sampleGraph();
      await repo.save(graph);

      final updated = graph.quizItems.first.withFsrsReview(
        difficulty: 4.5,
        stability: 10.0,
        fsrsState: 2,
        lapses: 0,
        interval: 10,
        nextReview: DateTime.utc(2025, 1, 11),
      );

      await repo.updateQuizItem(graph.withUpdatedQuizItem(updated), updated);

      final loaded = await repo.load();
      expect(loaded.quizItems.first.fsrsState, 2);
      expect(loaded.quizItems.first.stability, 10.0);
      // Other data unchanged
      expect(loaded.concepts, hasLength(2));
    });

    test('stores data under correct user path', () async {
      await repo.save(sampleGraph());

      // Verify the path structure: users/{userId}/data/graph/concepts/{id}
      final conceptDoc =
          await fakeFirestore
              .collection('users')
              .doc('test-user')
              .collection('data')
              .doc('graph')
              .collection('concepts')
              .doc('c1')
              .get();

      expect(conceptDoc.exists, isTrue);
      expect(conceptDoc.data()?['name'], 'Docker');
    });

    test('watch emits graph on load', () async {
      await repo.save(sampleGraph());

      final emitted = await repo.watch().first;
      expect(emitted.concepts, hasLength(2));
    });
  });
}
