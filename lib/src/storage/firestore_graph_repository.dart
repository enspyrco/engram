import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/concept.dart';
import '../models/document_metadata.dart';
import '../models/knowledge_graph.dart';
import '../models/quiz_item.dart';
import '../models/relationship.dart';
import 'graph_repository.dart';

/// Firestore-backed graph repository using subcollections:
///
/// ```
/// users/{userId}/graph/  (metadata doc)
///   ├─ concepts/          (one doc per concept)
///   ├─ relationships/     (one doc per relationship)
///   ├─ quizItems/         (one doc per quiz item)
///   └─ documents/         (one doc per ingested document)
/// ```
class FirestoreGraphRepository extends GraphRepository {
  FirestoreGraphRepository({
    required FirebaseFirestore firestore,
    required String userId,
  })  : _firestore = firestore,
        _userId = userId;

  final FirebaseFirestore _firestore;
  final String _userId;

  DocumentReference get _graphDoc =>
      _firestore.collection('users').doc(_userId).collection('data').doc('graph');

  CollectionReference get _concepts => _graphDoc.collection('concepts');
  CollectionReference get _relationships => _graphDoc.collection('relationships');
  CollectionReference get _quizItems => _graphDoc.collection('quizItems');
  CollectionReference get _documents => _graphDoc.collection('documents');

  @override
  Future<KnowledgeGraph> load() async {
    final results = await Future.wait([
      _concepts.get(),
      _relationships.get(),
      _quizItems.get(),
      _documents.get(),
    ]);

    final concepts = results[0].docs
        .map((d) => Concept.fromJson(d.data()! as Map<String, dynamic>))
        .toList();
    final relationships = results[1].docs
        .map((d) => Relationship.fromJson(d.data()! as Map<String, dynamic>))
        .toList();
    final quizItems = results[2].docs
        .map((d) => QuizItem.fromJson(d.data()! as Map<String, dynamic>))
        .toList();
    final documentMetadata = results[3].docs
        .map((d) => DocumentMetadata.fromJson(d.data()! as Map<String, dynamic>))
        .toList();

    return KnowledgeGraph(
      concepts: concepts,
      relationships: relationships,
      quizItems: quizItems,
      documentMetadata: documentMetadata,
    );
  }

  @override
  Future<void> save(KnowledgeGraph graph) async {
    final batch = _firestore.batch();

    // Delete existing data
    await _deleteCollection(_concepts, batch);
    await _deleteCollection(_relationships, batch);
    await _deleteCollection(_quizItems, batch);
    await _deleteCollection(_documents, batch);

    // Write new data
    for (final concept in graph.concepts) {
      batch.set(_concepts.doc(concept.id), concept.toJson());
    }
    for (final rel in graph.relationships) {
      batch.set(_relationships.doc(rel.id), rel.toJson());
    }
    for (final item in graph.quizItems) {
      batch.set(_quizItems.doc(item.id), item.toJson());
    }
    for (final meta in graph.documentMetadata) {
      batch.set(_documents.doc(meta.documentId), meta.toJson());
    }

    await batch.commit();
  }

  @override
  Future<void> updateQuizItem(KnowledgeGraph graph, QuizItem item) async {
    await _quizItems.doc(item.id).set(item.toJson());
  }

  @override
  Future<void> saveSplitData({
    required KnowledgeGraph graph,
    required List<Concept> concepts,
    required List<Relationship> relationships,
    required List<QuizItem> quizItems,
  }) async {
    final batch = _firestore.batch();
    for (final concept in concepts) {
      batch.set(_concepts.doc(concept.id), concept.toJson());
    }
    for (final rel in relationships) {
      batch.set(_relationships.doc(rel.id), rel.toJson());
    }
    for (final item in quizItems) {
      batch.set(_quizItems.doc(item.id), item.toJson());
    }
    await batch.commit();
  }

  @override
  Stream<KnowledgeGraph> watch() {
    // Combine four snapshot streams into one reactive KnowledgeGraph.
    // Re-emit whenever any subcollection changes.
    return _concepts.snapshots().asyncMap((_) => load());
  }

  Future<void> _deleteCollection(
    CollectionReference collection,
    WriteBatch batch,
  ) async {
    final snapshot = await collection.get();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
  }
}
