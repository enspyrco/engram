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
  late FirestoreGraphLoader loader;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    loader = FirestoreGraphLoader(
      firestore: fakeFirestore,
      userId: 'test-user',
    );
  });

  /// Helper to write sample data directly to Firestore subcollections.
  Future<void> seedFirestore(KnowledgeGraph graph) async {
    final graphDoc = fakeFirestore
        .collection('users')
        .doc('test-user')
        .collection('data')
        .doc('graph');

    for (final concept in graph.concepts) {
      await graphDoc
          .collection('concepts')
          .doc(concept.id)
          .set(concept.toJson());
    }
    for (final rel in graph.relationships) {
      await graphDoc.collection('relationships').doc(rel.id).set(rel.toJson());
    }
    for (final item in graph.quizItems) {
      await graphDoc.collection('quizItems').doc(item.id).set(item.toJson());
    }
    for (final meta in graph.documentMetadata) {
      await graphDoc
          .collection('documents')
          .doc(meta.documentId)
          .set(meta.toJson());
    }
  }

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

  group('FirestoreGraphLoader', () {
    test('load returns empty graph when no data exists', () async {
      final graph = await loader.load();
      expect(graph.concepts, isEmpty);
      expect(graph.relationships, isEmpty);
      expect(graph.quizItems, isEmpty);
      expect(graph.documentMetadata, isEmpty);
    });

    test('load reads all subcollections', () async {
      await seedFirestore(sampleGraph());

      final loaded = await loader.load();
      expect(loaded.concepts, hasLength(2));
      expect(loaded.concepts.first.id, 'c1');
      expect(loaded.relationships, hasLength(1));
      expect(loaded.quizItems, hasLength(1));
      expect(loaded.documentMetadata, hasLength(1));
    });

    test('load reads data under correct user path', () async {
      await seedFirestore(sampleGraph());

      final loaded = await loader.load();
      expect(loaded.concepts.any((c) => c.name == 'Docker'), isTrue);
      expect(loaded.concepts.any((c) => c.name == 'Kubernetes'), isTrue);
    });
  });
}
