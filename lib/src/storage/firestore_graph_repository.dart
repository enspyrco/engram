import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/concept.dart';
import '../models/document_metadata.dart';
import '../models/knowledge_graph.dart';
import '../models/quiz_item.dart';
import '../models/relationship.dart';
import 'graph_repository.dart';

/// Maximum number of operations per Firestore batch (Firestore limit is 500).
const _maxBatchOps = 500;

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
  }) : _firestore = firestore,
       _userId = userId;

  final FirebaseFirestore _firestore;
  final String _userId;

  DocumentReference get _graphDoc => _firestore
      .collection('users')
      .doc(_userId)
      .collection('data')
      .doc('graph');

  CollectionReference get _concepts => _graphDoc.collection('concepts');
  CollectionReference get _relationships =>
      _graphDoc.collection('relationships');
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

    final concepts =
        results[0].docs
            .map((d) => Concept.fromJson(d.data()! as Map<String, dynamic>))
            .toList();
    final relationships =
        results[1].docs
            .map(
              (d) => Relationship.fromJson(d.data()! as Map<String, dynamic>),
            )
            .toList();
    final quizItems =
        results[2].docs
            .map((d) => QuizItem.fromJson(d.data()! as Map<String, dynamic>))
            .toList();
    final documentMetadata =
        results[3].docs
            .map(
              (d) =>
                  DocumentMetadata.fromJson(d.data()! as Map<String, dynamic>),
            )
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
    // Query existing doc IDs in all subcollections.
    final existing = await Future.wait([
      _concepts.get(),
      _relationships.get(),
      _quizItems.get(),
      _documents.get(),
    ]);

    final existingConceptIds = existing[0].docs.map((d) => d.id).toSet();
    final existingRelIds = existing[1].docs.map((d) => d.id).toSet();
    final existingQuizIds = existing[2].docs.map((d) => d.id).toSet();
    final existingDocIds = existing[3].docs.map((d) => d.id).toSet();

    // Collect all write and delete operations, then commit in batched chunks.
    final ops = <void Function(WriteBatch)>[];

    // Upsert all current entities.
    final newConceptIds = <String>{};
    for (final concept in graph.concepts) {
      newConceptIds.add(concept.id);
      ops.add((b) => b.set(_concepts.doc(concept.id), concept.toJson()));
    }
    final newRelIds = <String>{};
    for (final rel in graph.relationships) {
      newRelIds.add(rel.id);
      ops.add((b) => b.set(_relationships.doc(rel.id), rel.toJson()));
    }
    final newQuizIds = <String>{};
    for (final item in graph.quizItems) {
      newQuizIds.add(item.id);
      ops.add((b) => b.set(_quizItems.doc(item.id), item.toJson()));
    }
    final newDocIds = <String>{};
    for (final meta in graph.documentMetadata) {
      newDocIds.add(meta.documentId);
      ops.add((b) => b.set(_documents.doc(meta.documentId), meta.toJson()));
    }

    // Delete orphans — docs that exist in Firestore but not in the new graph.
    for (final id in existingConceptIds.difference(newConceptIds)) {
      ops.add((b) => b.delete(_concepts.doc(id)));
    }
    for (final id in existingRelIds.difference(newRelIds)) {
      ops.add((b) => b.delete(_relationships.doc(id)));
    }
    for (final id in existingQuizIds.difference(newQuizIds)) {
      ops.add((b) => b.delete(_quizItems.doc(id)));
    }
    for (final id in existingDocIds.difference(newDocIds)) {
      ops.add((b) => b.delete(_documents.doc(id)));
    }

    await _commitBatched(ops);
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
    final ops = <void Function(WriteBatch)>[];
    for (final concept in concepts) {
      ops.add((b) => b.set(_concepts.doc(concept.id), concept.toJson()));
    }
    for (final rel in relationships) {
      ops.add((b) => b.set(_relationships.doc(rel.id), rel.toJson()));
    }
    for (final item in quizItems) {
      ops.add((b) => b.set(_quizItems.doc(item.id), item.toJson()));
    }
    await _commitBatched(ops);
  }

  @override
  Stream<KnowledgeGraph> watch() {
    // Combine four snapshot streams into one reactive KnowledgeGraph.
    // Re-emit whenever any subcollection changes.
    return _concepts.snapshots().asyncMap((_) => load());
  }

  /// Commit a list of batch operations in chunks of [_maxBatchOps].
  Future<void> _commitBatched(List<void Function(WriteBatch)> ops) async {
    for (var i = 0; i < ops.length; i += _maxBatchOps) {
      final batch = _firestore.batch();
      final end = (i + _maxBatchOps).clamp(0, ops.length);
      for (var j = i; j < end; j++) {
        ops[j](batch);
      }
      await batch.commit();
    }
  }
}
