import '../models/knowledge_graph.dart';
import '../models/quiz_item.dart';
import 'graph_analyzer.dart';

const maxSessionSize = 20;

/// Returns quiz items that are due for review from unlocked concepts,
/// sorted with foundational concepts first, then oldest-due,
/// capped at [maxItems] (defaults to [maxSessionSize], pass `null` for no cap).
List<QuizItem> scheduleDueItems(
  KnowledgeGraph graph, {
  DateTime? now,
  int? maxItems = maxSessionSize,
}) {
  final currentTime = now ?? DateTime.now().toUtc();
  final analyzer = GraphAnalyzer(graph);

  final unlockedIds = analyzer.unlockedConcepts.toSet();
  final foundationalIds = analyzer.foundationalConcepts.toSet();

  final due = graph.quizItems.where((item) {
    // Only include items from unlocked concepts
    if (!unlockedIds.contains(item.conceptId)) return false;
    final nextReview = DateTime.parse(item.nextReview);
    return !nextReview.isAfter(currentTime);
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
