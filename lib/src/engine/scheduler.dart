import '../models/knowledge_graph.dart';
import '../models/quiz_item.dart';
import 'graph_analyzer.dart';

const maxSessionSize = 20;

/// Returns quiz items that are due for review from unlocked concepts,
/// sorted with foundational concepts first, then oldest-due,
/// capped at [maxItems] (defaults to [maxSessionSize], pass `null` for no cap).
///
/// When [collectionId] is set, only items from concepts belonging to
/// documents in that collection are included. Unlocking remains graph-wide.
///
/// When [topicDocumentIds] is set, only items from concepts in those documents
/// are included. This takes precedence over [collectionId].
List<QuizItem> scheduleDueItems(
  KnowledgeGraph graph, {
  DateTime? now,
  int? maxItems = maxSessionSize,
  String? collectionId,
  Set<String>? topicDocumentIds,
}) {
  final currentTime = now ?? DateTime.now().toUtc();
  final analyzer = GraphAnalyzer(graph);

  final unlockedIds = analyzer.unlockedConcepts.toSet();
  final foundationalIds = analyzer.foundationalConcepts.toSet();

  // Build concept filter based on topic or collection scope.
  Set<String>? scopedConceptIds;
  if (topicDocumentIds != null) {
    scopedConceptIds =
        graph.concepts
            .where((c) => topicDocumentIds.contains(c.sourceDocumentId))
            .map((c) => c.id)
            .toSet();
  } else if (collectionId != null) {
    final collectionDocIds =
        graph.documentMetadata
            .where((m) => m.collectionId == collectionId)
            .map((m) => m.documentId)
            .toSet();
    scopedConceptIds =
        graph.concepts
            .where((c) => collectionDocIds.contains(c.sourceDocumentId))
            .map((c) => c.id)
            .toSet();
  }

  final due =
      graph.quizItems.where((item) {
        // Only include items from unlocked concepts
        if (!unlockedIds.contains(item.conceptId)) return false;
        // Filter by topic or collection when set
        if (scopedConceptIds != null &&
            !scopedConceptIds.contains(item.conceptId)) {
          return false;
        }
        return !item.nextReview.isAfter(currentTime);
      }).toList();

  // Sort: foundational first, then by due date within each tier
  due.sort((a, b) {
    final aFoundational = foundationalIds.contains(a.conceptId);
    final bFoundational = foundationalIds.contains(b.conceptId);
    if (aFoundational != bFoundational) {
      return aFoundational ? -1 : 1;
    }
    return a.nextReview.compareTo(b.nextReview);
  });

  if (maxItems != null && due.length > maxItems) {
    return due.sublist(0, maxItems);
  }
  return due;
}
