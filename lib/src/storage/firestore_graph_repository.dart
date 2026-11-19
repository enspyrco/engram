import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/concept.dart';
import '../models/document_metadata.dart';
import '../models/knowledge_graph.dart';
import '../models/quiz_item.dart';
import '../models/relationship.dart';

/// Read-only loader for the legacy Firestore subcollection graph layout:
///
/// ```
/// users/{userId}/data/graph/
///   ├─ concepts/          (one doc per concept)
///   ├─ relationships/     (one doc per relationship)
///   ├─ quizItems/         (one doc per quiz item)
///   └─ documents/         (one doc per ingested document)
/// ```
///
/// Used only by [seedFromFirestoreIfNeeded] for one-time migration of
/// pre-CRDT users to the local Drift database. All writes now go through
/// [DriftGraphRepository] and are synced via the CRDT sync_log transport.
class FirestoreGraphLoader {
  FirestoreGraphLoader({
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

  /// Loads the full knowledge graph from legacy Firestore subcollections.
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
}
